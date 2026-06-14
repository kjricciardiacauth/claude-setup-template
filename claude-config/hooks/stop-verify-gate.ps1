# Hook: Stop - verification gate against false "completed" claims.
# Reads the session ledger (~/.claude/sessions/log.md, written by
# session-log-toolcall) to see what STATE-CHANGING actions this turn performed.
# If there are new ones not yet gated, returns decision:block so the turn bounces
# back for a verification pass instead of ending on an unverified claim.
# Fires once per action-turn (stop_hook_active guard + per-session high-water
# mark). Silent on no-change turns. Fail-open. Bypass: $env:CLAUDE_SKIP_VERIFY_GATE = "1"
if ($env:CLAUDE_SKIP_VERIFY_GATE -eq "1") { exit 0 }
try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }
    $payload = $stdin | ConvertFrom-Json
    if ($payload.stop_hook_active) { exit 0 }
    if (-not $payload.session_id) { exit 0 }
    $id8 = $payload.session_id.Substring(0, 8)

    $sessionDir = "$env:USERPROFILE\.claude\sessions"
    $logFile    = "$sessionDir\log.md"
    if (-not (Test-Path $logFile)) { exit 0 }

    $mine = @(Get-Content $logFile -ErrorAction Stop | Where-Object { $_ -match "\[$id8\] -> " })
    $total = $mine.Count
    if ($total -eq 0) { exit 0 }

    $markFile = "$sessionDir\$id8.verified"
    $prior = 0
    if (Test-Path $markFile) {
        $raw = (Get-Content $markFile -Raw -ErrorAction SilentlyContinue).Trim()
        [int]::TryParse($raw, [ref]$prior) | Out-Null
    }
    if ($total -le $prior) { exit 0 }

    $new = $mine[$prior..($total - 1)]
    if ($new.Count -gt 12) { $new = $new[-12..-1] }
    $actionList = ($new | ForEach-Object { "  $_" }) -join "`n"
    Set-Content -Path $markFile -Value "$total" -ErrorAction SilentlyContinue

    $reason = @"
VERIFICATION GATE - do not end the turn claiming work is complete until you have verified it against fresh reads. A successful tool call (HTTP 200 / no error) is NOT proof of completion - confirm the resulting STATE.

State-changing actions this turn:
$actionList

For each, before saying done / fixed / sent / validated:
- External service writes (CRM / database / API record) -> re-fetch the record; confirm the field or status actually changed.
- Sends (email / chat / SMS) -> confirm it left as SENT. If it was only staged as a draft, say "drafted, not sent" - never claim sent.
- File edits -> re-read the changed region; if it was a fix, show the check / test output that proves it.
- git / build / deploy -> show the actual output (commit hash, deploy id, push result), not an assumption.

State the evidence first, then the claim. If you have ALREADY shown this evidence in your reply, briefly restate the proof and stop.
"@
    @{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress -Depth 5 | Write-Output
} catch { exit 0 }
