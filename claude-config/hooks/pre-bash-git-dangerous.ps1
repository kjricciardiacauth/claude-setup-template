# Hook: PreToolUse / Bash - warn before dangerous git commands.
#
# Reads stdin, inspects tool_input.command, emits a system-reminder
# warning if the command matches a known "dangerous git" pattern.
# Informational only - does not block. The user can override with
# explicit intent.
#
# Ships as-is. No customization needed - the patterns are universal.

$ErrorActionPreference = "SilentlyContinue"
$inputJson = [Console]::In.ReadToEnd()
if (-not $inputJson) { exit 0 }

try {
    $data = $inputJson | ConvertFrom-Json
} catch {
    exit 0
}

$command = $data.tool_input.command
if (-not $command) { exit 0 }

$warnings = @()

# git add -A / git add --all / git add . (literal dot, not ./somefile)
# Anchored on shell-separator or start so it does not match inside strings
if ($command -match '(?m)(?:^|[\s;&|])git\s+add\s+(?:-A|--all|\.)(?:\s|$)') {
    $warnings += "git add -A / git add . risks staging secrets, binaries, or unrelated changes. Stage specific files explicitly: 'git add path/to/file'."
}

# git push --force / git push --force-with-lease / git push -f
if ($command -match '(?m)(?:^|[\s;&|])git\s+push\b[^;&|]*(?:--force|--force-with-lease|\s-f(?:\s|$))') {
    $warnings += "git push --force: dangerous on main / shared branches. If rolling back, use 'git revert' (new commit), not 'git reset --hard' + force push."
}

# git reset --hard
if ($command -match '(?m)(?:^|[\s;&|])git\s+reset\s+--hard') {
    $warnings += "git reset --hard destroys local changes. Consider 'git revert' or 'git stash' first."
}

# --no-verify (skips git hooks)
if ($command -match '\-\-no-verify') {
    $warnings += "--no-verify skips git hooks. Never skip hooks unless explicitly asked. Fix the underlying issue instead."
}

# --no-gpg-sign
if ($command -match '\-\-no-gpg-sign') {
    $warnings += "--no-gpg-sign bypasses signing. Do not use unless explicitly requested."
}

# git rebase -i / git add -i (interactive, will hang in non-interactive context)
if ($command -match '(?m)(?:^|[\s;&|])git\s+(rebase|add)\s+(-i|--interactive)\b') {
    $warnings += "git rebase -i / git add -i: interactive commands hang in non-interactive contexts. Use non-interactive equivalents."
}

if ($warnings.Count -eq 0) { exit 0 }

$msg = "DANGEROUS GIT COMMAND WARNING:`n`n" + ($warnings -join "`n`n")

$reminder = @{
    hookSpecificOutput = @{
        hookEventName     = "PreToolUse"
        additionalContext = $msg
    }
} | ConvertTo-Json -Compress -Depth 5

Write-Output $reminder
