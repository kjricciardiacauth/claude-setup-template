# Hook: PreToolUse - log STATE-CHANGING tool calls to the ledger.
# Logs the edit tools always, and Bash only when the command looks mutating
# (so read-only shell calls don't trip the verification gate). Read-only tools
# (Read/Grep/Glob/etc.) are never logged. Fail-open. ASCII-only.
try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }
    $payload = $stdin | ConvertFrom-Json
    if (-not $payload.session_id) { exit 0 }
    $tool = [string]$payload.tool_name
    if (-not $tool) { exit 0 }

    $editTools = @('Write', 'Edit', 'MultiEdit', 'NotebookEdit')
    $brief = ''
    $log = $false

    if ($editTools -contains $tool) {
        $log = $true
        $fp = [string]$payload.tool_input.file_path
        if ($fp) { $brief = $fp }
    }
    elseif ($tool -eq 'Bash') {
        $cmd = [string]$payload.tool_input.command
        # Mutation heuristic: only log shell commands that can change state.
        $mut = 'git\s+(commit|push|add|merge|rebase|reset|tag|revert)|(^|[\s;&|])(rm|mv|cp|mkdir|tee|chmod|chown)\s|>>|(^|[\s;&|])[^|]*>|npm\s+(publish|install)|pip\s+install|deploy|wrangler\s+(deploy|publish)|docker\s+(build|push|run)|gh\s+(release|pr|issue)\s'
        if ($cmd -match $mut) { $log = $true; $brief = ($cmd -replace '\s+', ' ').Trim() }
    }

    if (-not $log) { exit 0 }
    $id8 = $payload.session_id.Substring(0, 8)
    if ($brief.Length -gt 80) { $brief = $brief.Substring(0, 80) }
    $dir = "$env:USERPROFILE\.claude\sessions"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -Path "$dir\log.md" -Value "[$id8] -> $tool $brief" -ErrorAction SilentlyContinue
} catch { exit 0 }
exit 0
