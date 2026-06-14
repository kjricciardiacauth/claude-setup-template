# Hook: PreToolUse (Bash) - GitHub identity safety, account-agnostic.
# Blocks `gh auth switch` (flips the machine-global active account -> races
# concurrent sessions). Warns on a `git push` whose origin is a bare
# https://github.com/ URL with no embedded account. Fail-open.
# Bypass: $env:CLAUDE_SKIP_GH_IDENTITY = "1"
if ($env:CLAUDE_SKIP_GH_IDENTITY -eq "1") { exit 0 }
try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }
    $payload = $stdin | ConvertFrom-Json
    $cmd = $payload.tool_input.command
    if (-not $cmd) { exit 0 }
    # Strip quoted substrings so a search/echo that merely MENTIONS the command isn't treated as an invocation.
    $bare = $cmd -replace '"[^"]*"', '' -replace "'[^']*'", ''

    if ($bare -match '\bgh\s+auth\s+switch\b') {
        $reason = "BLOCKED: 'gh auth switch' flips the machine-global active GitHub account and races every concurrent session. Don't switch accounts - instead embed the account in each remote URL (https://<account>@github.com/<owner>/<repo>.git), which routes to the right credential helper with no active-account change."
        @{ hookSpecificOutput = @{ hookEventName = "PreToolUse"; permissionDecision = "deny"; permissionDecisionReason = $reason } } | ConvertTo-Json -Compress -Depth 6 | Write-Output
        exit 0
    }

    if ($bare -match '\bgit\s+push\b') {
        $cwd = $payload.cwd; if (-not $cwd) { $cwd = (Get-Location).Path }
        try {
            $remote = & git -C "$cwd" remote get-url origin 2>$null
            if ($remote -match 'https://github\.com/' -and $remote -notmatch '@github\.com') {
                $reason = "GITHUB IDENTITY: this origin is a bare https://github.com/ URL with no embedded account. If you use more than one GitHub account on this machine, embed it so pushes route to the right credentials: git remote set-url origin https://<account>@github.com/<owner>/<repo>.git"
                @{ hookSpecificOutput = @{ hookEventName = "PreToolUse"; additionalContext = $reason } } | ConvertTo-Json -Compress -Depth 6 | Write-Output
            }
        } catch { }
    }
} catch { exit 0 }
