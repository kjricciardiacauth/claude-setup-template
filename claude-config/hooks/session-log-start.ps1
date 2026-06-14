# Hook: SessionStart - append a start marker to the cross-session ledger.
# The ledger (~/.claude/sessions/log.md) lets a concurrent session see recent
# activity, and is the data source the Stop verification gate reads.
# Fail-open (exit 0 on any error). ASCII-only.
try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }
    $payload = $stdin | ConvertFrom-Json
    if (-not $payload.session_id) { exit 0 }
    $id8 = $payload.session_id.Substring(0, 8)
    $dir = "$env:USERPROFILE\.claude\sessions"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -Path "$dir\log.md" -Value "[$id8] >>> session started" -ErrorAction SilentlyContinue
} catch { exit 0 }
exit 0
