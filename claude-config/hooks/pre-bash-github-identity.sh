#!/usr/bin/env bash
# Hook: PreToolUse (Bash) - GitHub identity safety, account-agnostic.
# Mac/Linux version of pre-bash-github-identity.ps1. Fail-open.
# Bypass: CLAUDE_SKIP_GH_IDENTITY=1
set -uo pipefail
[ "${CLAUDE_SKIP_GH_IDENTITY:-}" = "1" ] && exit 0
input_json=$(cat)
[ -z "$input_json" ] && exit 0
cmd=$(echo "$input_json" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0
# Strip quoted substrings so a mention isn't treated as an invocation.
bare=$(echo "$cmd" | sed -E 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g')

if echo "$bare" | grep -Eq '\bgh[[:space:]]+auth[[:space:]]+switch\b'; then
    reason="BLOCKED: 'gh auth switch' flips the machine-global active GitHub account and races every concurrent session. Don't switch accounts - instead embed the account in each remote URL (https://<account>@github.com/<owner>/<repo>.git), which routes to the right credential helper with no active-account change."
    jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$r}}'
    exit 0
fi

if echo "$bare" | grep -Eq '\bgit[[:space:]]+push\b'; then
    cwd=$(echo "$input_json" | jq -r '.cwd // empty' 2>/dev/null); [ -z "$cwd" ] && cwd=$(pwd)
    remote=$(git -C "$cwd" remote get-url origin 2>/dev/null || true)
    if echo "$remote" | grep -q 'https://github\.com/' && ! echo "$remote" | grep -q '@github\.com'; then
        reason="GITHUB IDENTITY: this origin is a bare https://github.com/ URL with no embedded account. If you use more than one GitHub account on this machine, embed it so pushes route to the right credentials: git remote set-url origin https://<account>@github.com/<owner>/<repo>.git"
        jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$r}}'
    fi
fi
exit 0
