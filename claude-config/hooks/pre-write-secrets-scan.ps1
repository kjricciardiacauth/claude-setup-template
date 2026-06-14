# Hook: PreToolUse / Write|Edit - block writing live secrets into any file.
# Scans the CONTENT being written for high-confidence secret patterns and DENIES
# the tool call if one is found. Secrets belong in environment variables or a
# gitignored .env / a secret manager, never committed to a file. ASCII-only.
$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $data = $raw | ConvertFrom-Json } catch { exit 0 }
$ti = $data.tool_input
if (-not $ti) { exit 0 }

$texts = @()
if ($ti.content)    { $texts += [string]$ti.content }
if ($ti.new_string) { $texts += [string]$ti.new_string }
if ($ti.edits)      { foreach ($e in $ti.edits) { if ($e.new_string) { $texts += [string]$e.new_string } } }
$blob = $texts -join "`n"
if (-not $blob) { exit 0 }

$patterns = @(
    @{ n = 'Private key block';       re = '-----BEGIN (?:RSA |EC |OPENSSH |PGP |DSA )?PRIVATE KEY-----' },
    @{ n = 'AWS access key id';       re = 'AKIA[0-9A-Z]{16}' },
    @{ n = 'Anthropic API key';       re = 'sk-ant-[A-Za-z0-9_\-]{24,}' },
    @{ n = 'OpenAI-style key';        re = 'sk-[A-Za-z0-9]{32,}' },
    @{ n = 'GitHub token';            re = '(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}' },
    @{ n = 'GitHub fine-grained PAT'; re = 'github_pat_[A-Za-z0-9_]{50,}' },
    @{ n = 'Slack token';             re = 'xox[baprs]-[A-Za-z0-9-]{12,}' },
    @{ n = 'Google API key';          re = 'AIza[0-9A-Za-z_\-]{35}' },
    @{ n = 'Stripe live key';         re = '(?:sk|rk)_live_[0-9a-zA-Z]{24,}' }
)
$hits = @()
foreach ($p in $patterns) { if ($blob -match $p.re) { $hits += $p.n } }
if ($hits.Count -eq 0) { exit 0 }

$fp = if ($ti.file_path) { [string]$ti.file_path } else { 'the target file' }
$reason = "BLOCKED by secrets-scan: content being written to '" + $fp + "' looks like a live secret (" + ($hits -join ', ') + "). Never write real credentials into a file. Put it in an environment variable or a gitignored .env / your secret manager and reference it via the environment. If this is a redacted placeholder, rephrase so it does not match a real-key shape."
$obj = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } }
$obj | ConvertTo-Json -Depth 6 -Compress
exit 0
