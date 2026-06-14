#!/usr/bin/env bash
# Hook: Stop - verification gate against false "completed" claims.
# Mac/Linux version of stop-verify-gate.ps1. Reads the ledger written by
# session-log-toolcall.sh. Fail-open. Bypass: CLAUDE_SKIP_VERIFY_GATE=1
set -uo pipefail
[ "${CLAUDE_SKIP_VERIFY_GATE:-}" = "1" ] && exit 0
input_json=$(cat)
[ -z "$input_json" ] && exit 0
active=$(echo "$input_json" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0
id=$(echo "$input_json" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$id" ] && exit 0
id8=${id:0:8}
dir="$HOME/.claude/sessions"
log="$dir/log.md"
[ -f "$log" ] || exit 0

mapfile -t mine < <(grep -F "[$id8] -> " "$log" 2>/dev/null)
total=${#mine[@]}
[ "$total" -eq 0 ] && exit 0

mark="$dir/$id8.verified"
prior=0
[ -f "$mark" ] && prior=$(tr -dc '0-9' < "$mark" 2>/dev/null) && prior=${prior:-0}
[ "$total" -le "$prior" ] && exit 0

start=$prior
[ $((total - prior)) -gt 12 ] && start=$((total - 12))
action_list=""
for ((i=start; i<total; i++)); do action_list+="  ${mine[$i]}"$'\n'; done
echo "$total" > "$mark" 2>/dev/null || true

reason="VERIFICATION GATE - do not end the turn claiming work is complete until you have verified it against fresh reads. A successful tool call (HTTP 200 / no error) is NOT proof of completion - confirm the resulting STATE.

State-changing actions this turn:
${action_list}
For each, before saying done / fixed / sent / validated:
- External service writes (CRM / database / API record) -> re-fetch the record; confirm the field or status actually changed.
- Sends (email / chat / SMS) -> confirm it left as SENT. If it was only staged as a draft, say \"drafted, not sent\" - never claim sent.
- File edits -> re-read the changed region; if it was a fix, show the check / test output that proves it.
- git / build / deploy -> show the actual output (commit hash, deploy id, push result), not an assumption.

State the evidence first, then the claim. If you have ALREADY shown this evidence in your reply, briefly restate the proof and stop."

jq -n --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
