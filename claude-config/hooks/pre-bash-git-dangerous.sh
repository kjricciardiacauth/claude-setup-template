#!/usr/bin/env bash
# Hook: PreToolUse / Bash - warn before dangerous git commands.
#
# Reads stdin, inspects tool_input.command, emits a system-reminder
# warning if the command matches a known "dangerous git" pattern.
# Informational only - does not block.
#
# Ships as-is. Universal patterns - no customization needed.
# This is the bash (Mac/Linux) version. The PowerShell equivalent for
# Windows is pre-bash-git-dangerous.ps1.

set -uo pipefail

input_json=$(cat)
[ -z "$input_json" ] && exit 0

command=$(echo "$input_json" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$command" ] && exit 0

warnings=()

# git add -A / git add --all / git add . (literal dot, not ./somefile)
if echo "$command" | grep -Eq '(^|[[:space:];&|])git[[:space:]]+add[[:space:]]+(-A|--all|\.)([[:space:]]|$)'; then
    warnings+=("git add -A / git add . risks staging secrets, binaries, or unrelated changes. Stage specific files explicitly: 'git add path/to/file'.")
fi

# git push --force / --force-with-lease / -f
if echo "$command" | grep -Eq '(^|[[:space:];&|])git[[:space:]]+push[^;&|]*(--force|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
    warnings+=("git push --force: dangerous on main / shared branches. If rolling back, use 'git revert' (new commit), not 'git reset --hard' + force push.")
fi

# git reset --hard
if echo "$command" | grep -Eq '(^|[[:space:];&|])git[[:space:]]+reset[[:space:]]+--hard'; then
    warnings+=("git reset --hard destroys local changes. Consider 'git revert' or 'git stash' first.")
fi

# --no-verify (skips git hooks)
if echo "$command" | grep -q -- '--no-verify'; then
    warnings+=("--no-verify skips git hooks. Never skip hooks unless explicitly asked. Fix the underlying issue instead.")
fi

# --no-gpg-sign
if echo "$command" | grep -q -- '--no-gpg-sign'; then
    warnings+=("--no-gpg-sign bypasses signing. Do not use unless explicitly requested.")
fi

# git rebase -i / git add -i (interactive, will hang in non-interactive context)
if echo "$command" | grep -Eq '(^|[[:space:];&|])git[[:space:]]+(rebase|add)[[:space:]]+(-i|--interactive)([[:space:]]|$)'; then
    warnings+=("git rebase -i / git add -i: interactive commands hang in non-interactive contexts. Use non-interactive equivalents.")
fi

[ ${#warnings[@]} -eq 0 ] && exit 0

# Build message - join warnings with blank lines
msg="DANGEROUS GIT COMMAND WARNING:"
for w in "${warnings[@]}"; do
    msg+=$'\n\n'"$w"
done

jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $msg}}'
