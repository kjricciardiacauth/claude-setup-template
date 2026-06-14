#!/usr/bin/env bash
# Hook: PreToolUse - log STATE-CHANGING tool calls to the ledger.
# Mac/Linux version of session-log-toolcall.ps1. Fail-open. ASCII-only.
set -uo pipefail
input_json=$(cat)
[ -z "$input_json" ] && exit 0
id=$(echo "$input_json" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$id" ] && exit 0
tool=$(echo "$input_json" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$tool" ] && exit 0

brief=""
log=0
case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit)
        log=1
        brief=$(echo "$input_json" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        ;;
    Bash)
        cmd=$(echo "$input_json" | jq -r '.tool_input.command // empty' 2>/dev/null)
        if echo "$cmd" | grep -Eq 'git[[:space:]]+(commit|push|add|merge|rebase|reset|tag|revert)|(^|[[:space:];&|])(rm|mv|cp|mkdir|tee|chmod|chown)[[:space:]]|>>|npm[[:space:]]+(publish|install)|pip[[:space:]]+install|deploy|wrangler[[:space:]]+(deploy|publish)|docker[[:space:]]+(build|push|run)|gh[[:space:]]+(release|pr|issue|project)[[:space:]]'; then
            log=1
            brief=$(echo "$cmd" | tr -s '[:space:]' ' ')
        fi
        ;;
esac
[ "$log" -eq 0 ] && exit 0

id8=${id:0:8}
brief=${brief:0:80}
dir="$HOME/.claude/sessions"
mkdir -p "$dir" 2>/dev/null || exit 0
echo "[$id8] -> $tool $brief" >> "$dir/log.md" 2>/dev/null || true
exit 0
