---
name: private
description: Explicitly approved local private-source collector
---

Run only entries listed in `kb.private_sources`. Each entry must set `approved_for_kb: true`. Do not scan home directories, mounted volumes, application data, or source trees by pattern.

For every extracted item, retain its configured source name, stable path or source key, modification time or version, normalized-content fingerprint, collection time, and access classification. Keep raw source material in KB routing state.

Keep semantic extraction and access classification here. Pass eligible canonical records to the scheduled daily-maintenance workflow; the knowledge-base prompt owns upstream projection. Do not create or mutate projection state in this collector.
