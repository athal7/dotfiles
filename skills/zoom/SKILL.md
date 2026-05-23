---
name: zoom
description: Zoom meeting captions — file locations and format
license: MIT
metadata:
  provides:
    - zoom
---

Zoom saves meeting captions to `~/Documents/Zoom/`. Each meeting gets a timestamped directory.

## File layout

```
~/Documents/Zoom/
  YYYY-MM-DD HH.MM.SS <Meeting Title>/
    meeting_saved_closed_caption.txt
```

## Caption format

```
[Speaker Name HH:MM:SS]
Spoken text from that speaker.

[Another Speaker HH:MM:SS]
Their spoken text.
```

Speaker names come from Zoom display names and may not match canonical names.
