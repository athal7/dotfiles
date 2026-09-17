#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/kb-enrich-collectors-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (want '$3' got '$2')"; fi; }
contains() { if grep -Fq -- "$2" "$3"; then ok "$1"; else bad "$1"; fi; }
not_contains() { if grep -Fq -- "$2" "$3"; then bad "$1"; else ok "$1"; fi; }

COMMAND="$WORK/kb-enrich.md"
SLACK="$WORK/slack.md"
ZOOM="$WORK/zoom.md"
chezmoi cat -S "$REPO_ROOT" "$HOME/.omp/agent/commands/kb-enrich.md" > "$COMMAND"
chezmoi cat -S "$REPO_ROOT" "$HOME/.config/kb/collectors/slack.md" > "$SLACK"
chezmoi cat -S "$REPO_ROOT" "$HOME/.config/kb/collectors/zoom.md" > "$ZOOM"

utc_boundary='2026-01-15T05:30:00+00:00'
local_day="$(UTC_BOUNDARY="$utc_boundary" python3 - <<'PY'
from datetime import datetime
from zoneinfo import ZoneInfo

instant = datetime.fromisoformat(__import__('os').environ['UTC_BOUNDARY'])
print(instant.astimezone(ZoneInfo('America/Chicago')).date())
PY
)"
check "converts explicit UTC prior-evening boundary to America/Chicago day" "$local_day" 2026-01-14
contains "uses local IANA timezone for implicit journal day" 'Resolve the local IANA timezone before calculating any implicit date' "$COMMAND"
contains "keeps local YYYY-MM-DD journal labels" $'Local journal labels remain `YYYY-MM-DD`' "$COMMAND"
contains "calculates implicit today in local IANA calendar" $'calculate `today` as the calendar date in that IANA timezone, never UTC' "$COMMAND"
contains "preserves explicit journal labels" 'for an explicit journal range, use the supplied labels unchanged' "$COMMAND"
contains "derives a half-open UTC collector window from local midnights" 'half-open UTC instant window from local midnight at the range start through local midnight after the inclusive range end' "$COMMAND"
contains "uses exact Calendar enumeration method" $'`list_calendars`' "$COMMAND"
contains "uses exact Calendar event listing method" $'`list_events`' "$COMMAND"
contains "uses exact Calendar event resolution method" $'`get_event`' "$COMMAND"
not_contains "avoids obsolete hyphenated Calendar event listing" $'`list-events`' "$COMMAND"
not_contains "avoids obsolete Calendar event detail method" $'`get-event-details`' "$COMMAND"

collector_window="$(python3 - <<'PY'
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

zone = ZoneInfo('America/Chicago')
start = date(2026, 1, 14)
inclusive_end = date(2026, 1, 15)
for day in (start, inclusive_end + timedelta(days=1)):
    print(datetime.combine(day, time.min, zone).astimezone(ZoneInfo('UTC')).isoformat())
PY
)"
check "models local-label range as half-open UTC collector window" "$collector_window" $'2026-01-14T06:00:00+00:00\n2026-01-16T06:00:00+00:00'

contains "uses authenticated Slack time-window search" $'`from:me after:<FROM> before:<TO>`' "$SLACK"
contains "retrieves same-conversation Slack context" 'For every authored message result, retrieve nearby messages in the same channel or DM conversation for context' "$SLACK"
contains "retains applicable Slack threads" 'retain its thread when applicable' "$SLACK"
not_contains "avoids raw Slack author-ID filtering" 'from:<author_id>' "$SLACK"

candidate_records=$(cat <<'EOF'
calendar-alpha|icaluid-generic|conference-generic|2026-01-14T23:30:00-06:00
calendar-beta|icaluid-generic|conference-generic|2026-01-14T23:30:00-06:00
calendar-alpha|icaluid-generic|conference-generic|2026-01-21T23:30:00-06:00
EOF
)
resolved_occurrences="$(printf '%s\n' "$candidate_records" | cut -d '|' -f2-4 | sort -u)"
resolved_occurrence_count="$(printf '%s\n' "$resolved_occurrences" | wc -l | tr -d ' ')"
check "generic duplicate-calendar copies collapse by resolved occurrence identity" "$resolved_occurrence_count" 2
contains "retains a distinct occurrence from the same generic series" 'icaluid-generic|conference-generic|2026-01-21T23:30:00-06:00' <(printf '%s\n' "$resolved_occurrences")

asset_records=$(cat <<'EOF'
conference-generic|2026-01-14T23:30:00-06:00|asset-first-occurrence
conference-generic|2026-01-21T23:30:00-06:00|asset-second-occurrence
conference-generic|2026-01-28T23:30:00-06:00|asset-wrong-occurrence
EOF
)
selected_assets=''
while IFS='|' read -r _ical_uid resolved_conference_id resolved_start; do
  while IFS='|' read -r asset_meeting_id asset_start_time asset_id; do
    if [ "$asset_meeting_id" = "$resolved_conference_id" ] && [ "$asset_start_time" = "$resolved_start" ]; then
      selected_assets+="$asset_id"$'\n'
    fi
  done <<< "$asset_records"
done <<< "$resolved_occurrences"
selected_assets="$(printf '%s' "$selected_assets" | sort -u)"
check "selects assets for both resolved generic occurrences" "$selected_assets" $'asset-first-occurrence\nasset-second-occurrence'
wrong_occurrence_selected=false
if printf '%s\n' "$selected_assets" | grep -Fxq 'asset-wrong-occurrence'; then
  wrong_occurrence_selected=true
fi
check "rejects a generic asset for a different occurrence" "$wrong_occurrence_selected" false

contains "enumerates all accessible calendars" $'Enumerate every accessible Google Calendar with `list_calendars`' "$ZOOM"
contains "lists events per enumerated calendar" $'For each calendar, index events from `<FROM>` to `<TO>`' "$ZOOM"
contains "resolves every Calendar candidate event" $'then call `get_event` for every candidate' "$ZOOM"
contains "deduplicates only resolved calendar mirrors" 'Deduplicate only duplicate-calendar mirrors of the same resolved occurrence' "$ZOOM"
contains "retains different recurring occurrences" 'retain distinct occurrences in the same series' "$ZOOM"
contains "forbids occurrence collapse by iCalUID or conference" 'never collapse different occurrences solely because their iCalUID or conference ID matches' "$ZOOM"
contains "requires asset meeting and occurrence-start match" $'its `meeting_id` equals the resolved event' "$ZOOM"
contains "matches asset start to resolved event start" "its \`start_time\` equals the resolved event's \`start.dateTime\`" "$ZOOM"
contains "forbids Zoom search capability fallback" 'do not add a search or capability fallback' "$ZOOM"

if [ "$fail" -ne 0 ]; then
  printf '%s kb-enrich collector recipe checks failed; %s passed\n' "$fail" "$pass" >&2
  exit 1
fi
printf 'All %s kb-enrich collector recipe checks passed.\n' "$pass"
