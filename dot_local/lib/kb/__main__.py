"""kb — build a local knowledge base from meeting transcripts and work tools.

Zoom's automated captions generate a live transcript during any meeting — pin the
Transcripts button to the toolbar, enable captions, and click Save Transcript before
the meeting ends. Zoom writes meeting_saved_closed_caption.txt to ~/Documents/Zoom/.

A LaunchAgent (zoom-capture.plist) watches that directory and runs `kb meeting`
automatically. The pipeline: parse captions → summarize via local LLM (LM Studio) →
write ~/meetings/YYYY-MM-DD-<slug>.md → extract people/project/decision data → merge
into ~/meetings/knowledge/ profiles → create Apple Reminders for action items.

A daily LaunchAgent (kb-enrich.plist) runs `kb enrich` to supplement the knowledge base
with context from Slack DMs, Linear projects, and GitHub repos.

All processing runs on a local LLM — no meeting content leaves the machine. Zoom's
native captions also produce better speaker diarization than third-party transcription
tools, since Zoom has direct access to each participant's audio stream.

Usage:
    python3 -m kb meeting [/path/to/caption.txt]
    python3 -m kb enrich [--slack] [--linear] [--github] [--since HOURS] [--dry-run]

Requires PYTHONPATH=~/.local/lib.
"""
import sys, traceback


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(0 if sys.argv[1:] == ["--help"] or sys.argv[1:] == ["-h"] else 1)

    subcommand = sys.argv[1]
    remaining = sys.argv[2:]

    if subcommand == "meeting":
        from kb.meeting import main as meeting_main, report_error, log
        try:
            meeting_main(remaining)
        except Exception as e:
            log(f"FATAL: {e}")
            traceback.print_exc(file=sys.stderr)
            report_error("unknown meeting", str(e))
            sys.exit(1)

    elif subcommand == "enrich":
        from kb.enrich import main as enrich_main, log
        try:
            enrich_main(remaining)
        except Exception as e:
            log(f"FATAL: {e}")
            traceback.print_exc(file=sys.stderr)
            sys.exit(1)

    else:
        print(f"Unknown subcommand: {subcommand}", file=sys.stderr)
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
