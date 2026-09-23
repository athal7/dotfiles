#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (want '$3' got '$2')"; fi; }
contains() { if grep -Fq -- "$2" "$3"; then ok "$1"; else bad "$1"; fi; }
not_contains() { if grep -Fq -- "$2" "$3"; then bad "$1"; else ok "$1"; fi; }

assert_collector_report() {
  local label="$1" record="$2"
  local collector terminal coverage reasons discovered read_count eligible known_omitted out_of_allowlist extra
  IFS='|' read -r collector terminal coverage reasons discovered read_count eligible known_omitted out_of_allowlist extra <<< "$record"
  if [ -z "$collector" ] || [ -n "$extra" ]; then bad "$label has nine fields"; return; fi
  case "$terminal" in succeeded|'succeeded with no eligible evidence'|failed) ;; *) bad "$label has terminal state"; return;; esac
  case "$coverage" in exhaustive|non-exhaustive|not-applicable) ;; *) bad "$label has coverage state"; return;; esac
  if [ "$coverage" != exhaustive ] && [ -z "$reasons" ]; then bad "$label has coverage reason"; return; fi
  for count in "$discovered" "$read_count" "$eligible" "$known_omitted" "$out_of_allowlist"; do
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then bad "$label has integer counts"; return; fi
  done
  ok "$label has terminal status, coverage state/reason, and counts"
}

COMMAND="$WORK/kb-enrich.md"
SLACK="$WORK/slack.md"
GH="$WORK/gh.md"
ZOOM="$WORK/zoom.md"
cp "$REPO_ROOT/dot_agents/prompts/knowledge-base.md" "$COMMAND"
chezmoi cat -S "$REPO_ROOT" "$HOME/.config/kb/collectors/slack.md" > "$SLACK"
chezmoi cat -S "$REPO_ROOT" "$HOME/.config/kb/collectors/gh.md" > "$GH"
chezmoi cat -S "$REPO_ROOT" "$HOME/.config/kb/collectors/zoom.md" > "$ZOOM"

contains "defines shared collector report identity" 'collector: <configured collector name>' "$COMMAND"
contains "defines shared collector terminal status" 'terminal_status: succeeded | succeeded with no eligible evidence | failed' "$COMMAND"
contains "defines independent shared coverage state" 'state: exhaustive | non-exhaustive | not-applicable' "$COMMAND"
contains "defines all shared collector counts" 'out_of_allowlist: <integer>' "$COMMAND"
contains "requires explicit pagination coverage reason" 'paginated source cannot page through requested scope' "$COMMAND"

contains "discovers Slack conversations before history collection" 'Discover every channel, DM, and group DM that the authenticated user can access' "$SLACK"
contains "declares Slack 200-message bound" 'read at most the most recent 200 messages' "$SLACK"
contains "uses two bounded Slack history pages" 'no more than two history pages of 100 messages each' "$SLACK"
contains "retains Slack conversation and thread context" 'the thread parent, and applicable replies with their parent/reply relationship' "$SLACK"
contains "excludes Slack bot sender markers" 'bot-message subtype, or another automated sender marker' "$SLACK"
contains "redacts Slack credential values" '[REDACTED_CREDENTIAL]' "$SLACK"
contains "reports bounded Slack coverage as non-exhaustive" 'bounded 200-message per-conversation history' "$SLACK"
not_contains "avoids Slack search as collection source" 'Search with search_messages' "$SLACK"

slack_history=''
for index in $(seq 1 198); do slack_history+="channel-alpha|user|thread-parent|message-$index"$'\n'; done
slack_history+='channel-alpha|bot|thread-parent|Automated notification'$'\n'
slack_history+='dm-beta|user|thread-reply|token=secret-value'$'\n'
slack_history+='channel-alpha|user|thread-reply|message-beyond-bound'
bounded_slack_history="$(printf '%s\n' "$slack_history" | head -n 200)"
retained_slack="$(printf '%s\n' "$bounded_slack_history" | awk -F '|' '$2 == "user" { print $1 "|" $3 "|" $4 }' | sed -E 's/(token=)[^[:space:]]+/\1[REDACTED_CREDENTIAL]/')"
check "bounds discovered Slack history to 200 messages" "$(printf '%s\n' "$bounded_slack_history" | wc -l | tr -d ' ')" 200
check "excludes bot noise from bounded Slack history" "$(printf '%s\n' "$retained_slack" | grep -c 'Automated notification' || true)" 0
check "retains authored Slack evidence within the bound" "$(printf '%s\n' "$retained_slack" | wc -l | tr -d ' ')" 199
check "redacts credential-bearing Slack values" "$(printf '%s\n' "$retained_slack" | tail -n 1)" 'dm-beta|thread-reply|token=[REDACTED_CREDENTIAL]'
check "does not retain Slack evidence beyond the bound" "$(printf '%s\n' "$retained_slack" | grep -c 'message-beyond-bound' || true)" 0

contains "reports GitHub out-of-allowlist activity" 'organization identity, observed time, and exclusion reason' "$GH"
contains "reports each missing configured GitHub organization" 'for each configured eligible organization that has no result' "$GH"
contains "does not infer GitHub eligibility" 'Do not infer eligibility, change allowlist configuration, or set any' "$GH"
contains "reports GitHub pagination as non-exhaustive coverage" 'paginated organization query cannot continue' "$GH"

configured_eligible_orgs=$'eligible-org\nomitted-org'
collected_github_orgs='eligible-org'
github_scope_report=''
while IFS= read -r configured_org; do
  if grep -Fxq "$configured_org" <<< "$collected_github_orgs"; then github_scope_report+="$configured_org:eligible evidence"$'\n';
  else github_scope_report+="$configured_org:configured allowlist omission"$'\n'; fi
done <<< "$configured_eligible_orgs"
github_scope_report="$(printf '%s' "$github_scope_report")"$'\nother-org:out-of-allowlist activity'
check "keeps GitHub omissions and out-of-allowlist activity separate" "$github_scope_report" $'eligible-org:eligible evidence\nomitted-org:configured allowlist omission\nother-org:out-of-allowlist activity'

contains "enumerates all accessible calendars" 'Enumerate every accessible Google Calendar' "$ZOOM"
contains "deduplicates only resolved calendar mirrors" 'Deduplicate only duplicate-calendar mirrors of the same resolved occurrence' "$ZOOM"
contains "requires exact Zoom meeting identifier" 'Retain an asset only when its' "$ZOOM"
contains "requires exact Zoom UUID and start identity" 'returned by Zoom' "$ZOOM"
contains "requires matching Calendar and Zoom series identity for fallback" 'explicit returned Zoom series identity that exactly matches that resolved Calendar series identity' "$ZOOM"
contains "records fallback occurrence and series provenance" 'the resolved occurrence identity, the resolved series identity, the returned series start timestamp' "$ZOOM"
contains "keeps Calendar notes and attachments separate" 'Store Calendar notes and Calendar attachments as separate Calendar evidence' "$ZOOM"
contains "keeps Zoom evidence types separate" 'Store Zoom meeting summaries, My Notes, and raw transcripts as separate Zoom evidence records' "$ZOOM"
contains "reports Zoom pagination as non-exhaustive coverage" 'Calendar lists, event lists, or Zoom asset pages cannot page through requested scope' "$ZOOM"

candidate_records=$'calendar-alpha|icaluid-generic|conference-generic|2026-01-14T23:30:00-06:00\ncalendar-beta|icaluid-generic|conference-generic|2026-01-14T23:30:00-06:00\ncalendar-alpha|icaluid-generic|conference-generic|2026-01-21T23:30:00-06:00'
resolved_occurrences="$(printf '%s\n' "$candidate_records" | cut -d '|' -f2-4 | sort -u)"
check "deduplicates only duplicate Calendar occurrence mirrors" "$(printf '%s\n' "$resolved_occurrences" | wc -l | tr -d ' ')" 2
contains "retains distinct recurring Calendar occurrences" 'icaluid-generic|conference-generic|2026-01-21T23:30:00-06:00' <(printf '%s\n' "$resolved_occurrences")

resolved_meeting_id='conference-generic'
resolved_series_identity='calendar-series-1:icaluid-generic'
resolved_occurrence_start='2026-01-21T23:30:00-06:00'
series_start='2026-01-14T23:30:00-06:00'
reconcile_zoom_asset() {
  local asset_meeting_id asset_meeting_uuid asset_meeting_start asset_series_identity
  IFS='|' read -r asset_meeting_id asset_meeting_uuid asset_meeting_start asset_series_identity <<< "$1"
  if [ -z "$asset_meeting_uuid" ]; then printf 'rejected';
  elif [ "$asset_meeting_id" = "$resolved_meeting_id" ] && [ "$asset_meeting_start" = "$resolved_occurrence_start" ]; then printf 'exact occurrence';
  elif [ "$asset_meeting_id" = "$resolved_meeting_id" ] && [ "$asset_meeting_start" = "$series_start" ] && [ "$asset_series_identity" = "$resolved_series_identity" ]; then printf 'series-start fallback';
  else printf 'rejected'; fi
}
exact_asset='conference-generic|meeting-uuid-1|2026-01-21T23:30:00-06:00|calendar-series-1:icaluid-generic'
unrelated_asset='other-conference|meeting-uuid-3|2026-01-21T23:30:00-06:00|calendar-series-1:icaluid-generic'
wrong_start_asset='conference-generic|meeting-uuid-4|2026-01-28T23:30:00-06:00|calendar-series-1:icaluid-generic'
fallback_asset='conference-generic|meeting-uuid-2|2026-01-14T23:30:00-06:00|calendar-series-1:icaluid-generic'
wrong_series_fallback_asset='conference-generic|meeting-uuid-5|2026-01-14T23:30:00-06:00|other-series:icaluid-generic'
missing_series_fallback_asset='conference-generic|meeting-uuid-6|2026-01-14T23:30:00-06:00|'
check "reconciles the exact Zoom recurring occurrence" "$(reconcile_zoom_asset "$exact_asset")" 'exact occurrence'
check "rejects an unrelated Zoom meeting identity" "$(reconcile_zoom_asset "$unrelated_asset")" rejected
check "rejects a matching Zoom meeting ID with wrong occurrence time" "$(reconcile_zoom_asset "$wrong_start_asset")" rejected
check "accepts stale recurring-series Zoom time only with matching series identity" "$(reconcile_zoom_asset "$fallback_asset")" 'series-start fallback'
check "rejects stale recurring-series Zoom time for another series" "$(reconcile_zoom_asset "$wrong_series_fallback_asset")" rejected
check "rejects stale recurring-series Zoom time without series identity" "$(reconcile_zoom_asset "$missing_series_fallback_asset")" rejected
check "retains exact Zoom UUID for the reconciled asset" "$(cut -d '|' -f2 <<< "$exact_asset")" 'meeting-uuid-1'

assert_collector_report "reports Slack terminal and bounded coverage" 'slack|succeeded|non-exhaustive|bounded 200-message per-conversation history; pagination unavailable|8|8|3|0|0'
assert_collector_report "reports GitHub partial configured scope" 'gh|succeeded|non-exhaustive|configured allowlist omission; pagination unavailable|3|1|2|1|1'
assert_collector_report "reports Zoom paginated scope" 'zoom|succeeded with no eligible evidence|non-exhaustive|pagination unavailable|12|10|0|2|0'

if [ "$fail" -ne 0 ]; then
  printf '%s kb-enrich collector recipe checks failed; %s passed\n' "$fail" "$pass" >&2
  exit 1
fi
printf 'All %s kb-enrich collector recipe checks passed.\n' "$pass"
