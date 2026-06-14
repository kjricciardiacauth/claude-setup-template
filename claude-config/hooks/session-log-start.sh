#!/usr/bin/env bash
# Hook: SessionStart - append a start marker to the cross-session ledger.
# Mac/Linux version of session-log-start.ps1. Fail-open. ASCII-only.
set -uo pipefail
input_json=$(cat)
[ -z "$input_json" ] && exit 0
id=$(echo "$input_json" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$id" ] && exit 0
id8=${id:0:8}
dir="$HOME/.claude/sessions"
mkdir -p "$dir" 2>/dev/null || exit 0
echo "[$id8] >>> session started" >> "$dir/log.md" 2>/dev/null || true
exit 0
