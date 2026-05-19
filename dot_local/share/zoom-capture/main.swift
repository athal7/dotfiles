// zoom-capture: Daemon that captures Zoom call audio via macOS per-process CATap
// Compile: swiftc -O -framework CoreAudio -framework AVFoundation -framework UserNotifications -o zoom-capture main.swift
// Requires: macOS 14.2+ (CATap), macOS 26.0+ for bundleID-based tap
// Runs as a persistent LaunchAgent (Aqua session) so notifications and audio work

import Foundation
import CoreAudio
import AVFoundation
import UserNotifications

// MARK: - Logging

func log(_ message: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    fputs("[\(ts)] zoom-capture: \(message)\n", stderr)
}

// MARK: - State Machine

enum DaemonState {
    case idle
    case prompting(since: Date)
    case recording(engine: AVAudioEngine, tapID: AudioObjectID, file: AVAudioFile, wavPath: String)
    case skipped
    case postprocessing
}

// MARK: - Global State (single-threaded via DispatchQueue.main)

var state: DaemonState = .idle
var pollTimer: DispatchSourceTimer?
var promptTimer: DispatchSourceTimer?
var pendingNotificationID: String? = nil

// MARK: - Process Detection

func zoomMainPID() -> pid_t? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    task.arguments = ["-x", "zoom.us"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    try? task.run()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let str = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
          let pid = pid_t(str) else { return nil }
    return pid
}

func isZoomCallActive() -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    task.arguments = ["-f", "(aomhost|CptHost|caphost)"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    try? task.run()
    task.waitUntilExit()
    return task.terminationStatus == 0
}

// MARK: - Calendar Lookup

func currentMeetingTitle() -> String? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    task.arguments = ["ical", "list", "-f", "now", "-t", "+30m", "-n", "1", "-o", "json"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    do {
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty else { return nil }
        // ical -o json returns an array of event objects
        if let events = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let first = events.first,
           let title = first["title"] as? String,
           !title.isEmpty {
            return title
        }
        // Fallback: single object
        if let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let title = event["title"] as? String,
           !title.isEmpty {
            return title
        }
        return nil
    } catch {
        return nil
    }
}

// MARK: - WAV Output Path

func newWavPath() -> URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let dir = home.appendingPathComponent("meetings/raw")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HHmmss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    let name = "\(formatter.string(from: Date())).wav"
    return dir.appendingPathComponent(name)
}

// MARK: - CoreAudio Tap Helpers

/// Find the AudioObjectID of the process that owns the given PID.
func audioObjectID(forPID pid: pid_t) -> AudioObjectID? {
    // Enumerate all process objects registered with the HAL
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize)
    guard status == noErr, dataSize > 0 else { return nil }

    let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
    var objectList = [AudioObjectID](repeating: 0, count: count)
    status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &objectList)
    guard status == noErr else { return nil }

    var pidAddr = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyPID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    for objectID in objectList {
        var foundPID: pid_t = 0
        var pidSize = UInt32(MemoryLayout<pid_t>.size)
        let pidStatus = AudioObjectGetPropertyData(objectID, &pidAddr, 0, nil, &pidSize, &foundPID)
        if pidStatus == noErr, foundPID == pid {
            return objectID
        }
    }
    return nil
}

// MARK: - Recording

func startRecording(zoomPID: pid_t) {
    let outputURL = newWavPath()
    log("Starting recording → \(outputURL.path)")

    // Build tap description — prefer bundleID API on macOS 26+
    var tapID: AudioObjectID = kAudioObjectUnknown

    // Build tap description.
    // On macOS 26+, use bundleIDs so the tap survives Zoom restarts.
    // On older macOS, fall back to PID → AudioObjectID lookup.
    let tapDesc: CATapDescription
    if #available(macOS 26.0, *) {
        tapDesc = CATapDescription()
        tapDesc.bundleIDs = ["us.zoom.xos"]
        tapDesc.isProcessRestoreEnabled = true
    } else {
        guard let zoomAudioObjID = audioObjectID(forPID: zoomPID) else {
            log("ERROR: could not find AudioObjectID for Zoom PID \(zoomPID) — aborting recording")
            state = .idle
            return
        }
        tapDesc = CATapDescription(stereoMixdownOfProcesses: [zoomAudioObjID])
    }
    tapDesc.name = "zoom-capture"
    tapDesc.isPrivate = true
    tapDesc.muteBehavior = .unmuted

    let createStatus = AudioHardwareCreateProcessTap(tapDesc, &tapID)
    guard createStatus == noErr, tapID != kAudioObjectUnknown else {
        log("ERROR: AudioHardwareCreateProcessTap failed: \(createStatus)")
        state = .idle
        return
    }
    log("CATap created, AudioObjectID=\(tapID)")

    // Wire up AVAudioEngine with the tap as input device
    let engine = AVAudioEngine()
    let inputNode = engine.inputNode

    guard let auRef = inputNode.audioUnit else {
        log("ERROR: could not get audioUnit from inputNode")
        AudioHardwareDestroyProcessTap(tapID)
        state = .idle
        return
    }

    var tapIDValue = tapID
    let setStatus = AudioUnitSetProperty(
        auRef,
        AudioUnitPropertyID(kAudioOutputUnitProperty_CurrentDevice),
        kAudioUnitScope_Global,
        0,
        &tapIDValue,
        UInt32(MemoryLayout<AudioObjectID>.size)
    )
    guard setStatus == noErr else {
        log("ERROR: AudioUnitSetProperty(CurrentDevice) failed: \(setStatus)")
        AudioHardwareDestroyProcessTap(tapID)
        state = .idle
        return
    }

    let format = inputNode.outputFormat(forBus: 0)
    log("Tap format: \(format)")

    let fileSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 48000.0,
        AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
    ]

    let audioFile: AVAudioFile
    do {
        audioFile = try AVAudioFile(forWriting: outputURL, settings: fileSettings)
    } catch {
        log("ERROR: could not create wav file: \(error)")
        AudioHardwareDestroyProcessTap(tapID)
        state = .idle
        return
    }

    inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
        do {
            try audioFile.write(from: buffer)
        } catch {
            // Write errors are non-fatal; log and continue
            log("WARNING: wav write error: \(error)")
        }
    }

    do {
        try engine.start()
    } catch {
        log("ERROR: AVAudioEngine.start failed: \(error)")
        inputNode.removeTap(onBus: 0)
        AudioHardwareDestroyProcessTap(tapID)
        state = .idle
        return
    }

    log("Recording started")
    state = .recording(engine: engine, tapID: tapID, file: audioFile, wavPath: outputURL.path)
}

func stopRecording(launchPostProcessor: Bool) {
    guard case .recording(let engine, let tapID, _, let wavPath) = state else { return }
    log("Stopping recording (launchPostProcessor=\(launchPostProcessor))")

    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    AudioHardwareDestroyProcessTap(tapID)

    log("WAV closed: \(wavPath)")

    if launchPostProcessor {
        state = .postprocessing
        launchPostProcess(wavPath: wavPath)
    } else {
        state = .idle
    }
}

// MARK: - Post-processor

func launchPostProcess(wavPath: String) {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let scriptPath = "\(home)/.local/bin/zoom-postprocess"

    guard FileManager.default.fileExists(atPath: scriptPath) else {
        log("Post-processor not found at \(scriptPath) — skipping")
        state = .idle
        return
    }

    let postprocess = Process()
    postprocess.executableURL = URL(fileURLWithPath: scriptPath)
    postprocess.arguments = [wavPath]
    // Fire and forget — state moves back to idle regardless
    do {
        try postprocess.run()
        log("Post-processor launched with: \(wavPath)")
    } catch {
        log("WARNING: could not launch post-processor: \(error)")
    }
    state = .idle
}

// MARK: - Notifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        guard id == pendingNotificationID else {
            completionHandler()
            return
        }
        cancelPromptTimer()
        pendingNotificationID = nil

        DispatchQueue.main.async {
            switch response.actionIdentifier {
            case "RECORD":
                log("Notification: [Record] selected")
                handleRecordDecision(shouldRecord: true)
            case "SKIP", UNNotificationDismissActionIdentifier, UNNotificationDefaultActionIdentifier:
                log("Notification: [Skip] selected (action=\(response.actionIdentifier))")
                handleRecordDecision(shouldRecord: false)
            default:
                log("Notification: unknown action '\(response.actionIdentifier)' — skipping")
                handleRecordDecision(shouldRecord: false)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + sound even if this process is frontmost
        completionHandler([.banner, .sound])
    }
}

let notificationDelegate = NotificationDelegate()

func setupNotifications() {
    let center = UNUserNotificationCenter.current()
    center.delegate = notificationDelegate

    let recordAction = UNNotificationAction(
        identifier: "RECORD",
        title: "Record",
        options: []
    )
    let skipAction = UNNotificationAction(
        identifier: "SKIP",
        title: "Skip",
        options: []
    )
    let category = UNNotificationCategory(
        identifier: "ZOOM_CALL",
        actions: [recordAction, skipAction],
        intentIdentifiers: [],
        options: []
    )
    center.setNotificationCategories([category])

    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if let error = error {
            log("Notification auth error: \(error)")
        } else {
            log("Notification auth granted=\(granted)")
        }
    }
}

func postCallDetectedNotification(meetingTitle: String?) {
    guard case .idle = state else { return }

    let notifID = UUID().uuidString
    pendingNotificationID = notifID

    let content = UNMutableNotificationContent()
    content.title = "Zoom call detected"
    content.body = meetingTitle ?? "Record this call?"
    content.categoryIdentifier = "ZOOM_CALL"
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    let request = UNNotificationRequest(identifier: notifID, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            log("Failed to post notification: \(error)")
            // Default to skip on notification failure
            DispatchQueue.main.async {
                cancelPromptTimer()
                pendingNotificationID = nil
                handleRecordDecision(shouldRecord: false)
            }
        }
    }

    state = .prompting(since: Date())
    log("Notification posted (id=\(notifID), meeting=\(meetingTitle ?? "<none>"))")

    // 15-second timeout — default to skip
    startPromptTimer()
}

// MARK: - Prompt timer

func startPromptTimer() {
    cancelPromptTimer()
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + 15.0)
    timer.setEventHandler {
        guard case .prompting = state else { return }
        log("Notification timed out (15s) — defaulting to Skip")
        if let id = pendingNotificationID {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
        }
        pendingNotificationID = nil
        handleRecordDecision(shouldRecord: false)
    }
    timer.resume()
    promptTimer = timer
}

func cancelPromptTimer() {
    promptTimer?.cancel()
    promptTimer = nil
}

// MARK: - Decision handler (called from main queue)

func handleRecordDecision(shouldRecord: Bool) {
    // If call already ended while prompting, treat as idle regardless
    guard isZoomCallActive() else {
        log("Call ended before decision — nothing to do")
        state = .idle
        return
    }

    if shouldRecord {
        let pid = zoomMainPID() ?? 0
        startRecording(zoomPID: pid)
    } else {
        state = .skipped
        log("Recording skipped")
    }
}

// MARK: - Poll loop

func startPolling() {
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + 2.0, repeating: 2.0)
    timer.setEventHandler { pollTick() }
    timer.resume()
    pollTimer = timer
}

func pollTick() {
    let callActive = isZoomCallActive()

    switch state {
    case .idle:
        if callActive {
            log("Zoom call detected — fetching calendar title…")
            // Fetch meeting title off main queue to avoid blocking
            DispatchQueue.global(qos: .userInitiated).async {
                let title = currentMeetingTitle()
                DispatchQueue.main.async {
                    postCallDetectedNotification(meetingTitle: title)
                }
            }
        }

    case .prompting:
        // Waiting for user response or timeout — nothing to do on tick
        // If call ended before they responded, the next tick will handle cleanup
        if !callActive {
            log("Call ended during prompt — cancelling")
            cancelPromptTimer()
            if let id = pendingNotificationID {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
            }
            pendingNotificationID = nil
            state = .idle
        }

    case .recording:
        if !callActive {
            log("Call helpers exited — stopping recording")
            stopRecording(launchPostProcessor: true)
        }

    case .skipped:
        if !callActive {
            log("Skipped call ended — returning to idle")
            state = .idle
        }

    case .postprocessing:
        // post-processor is fire-and-forget; state is already idle by the time we poll
        break
    }
}

// MARK: - SIGTERM handler

func setupSignalHandling() {
    signal(SIGTERM, SIG_IGN)
    let sigSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigSource.setEventHandler {
        log("Received SIGTERM — shutting down")
        if case .recording = state {
            stopRecording(launchPostProcessor: false)
        }
        exit(0)
    }
    sigSource.resume()
    // Keep a reference so it isn't deallocated
    _ = Unmanaged.passRetained(sigSource as AnyObject)
}

// MARK: - Entry Point

log("zoom-capture starting (pid=\(ProcessInfo.processInfo.processIdentifier))")
setupSignalHandling()
setupNotifications()
startPolling()
log("Polling for Zoom calls every 2 seconds")
RunLoop.main.run()
