# Phase 1a: Active Enforcement Hooks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four always-active, project-agnostic enforcement hooks to the template so a user pointing Claude Code at the repo gets a better session out of the box: a session activity ledger, a verification-before-completion gate, a secrets-write scanner, and a GitHub identity guard.

**Architecture:** Hooks read the tool-call JSON on stdin and either log, warn (`additionalContext`), block a Stop (`decision: block`), or deny a tool (`permissionDecision: deny`). All fail **open** (exit 0 on any error) so a hook never hard-breaks a turn. The verification gate consumes a ledger written by the activity logger, so those two ship together. Every hook is sanitized — no account/org/service proper nouns — and ships in both `.ps1` (Windows) and `.sh` (Mac/Linux), ASCII-only.

**Tech Stack:** PowerShell 5.1+ (Windows), bash + `jq` (Mac/Linux), Claude Code hook events (`SessionStart`, `PreToolUse`, `Stop`).

---

## File Structure

| File | Responsibility |
|---|---|
| `claude-config/hooks/session-log-start.ps1` / `.sh` | On `SessionStart`, append a start marker to the ledger. |
| `claude-config/hooks/session-log-toolcall.ps1` / `.sh` | On `PreToolUse`, append a line for state-changing tool calls (edits + mutating Bash) to the ledger. |
| `claude-config/hooks/stop-verify-gate.ps1` / `.sh` | On `Stop`, block once per action-turn if new state-changing actions weren't verified. Reads the ledger. |
| `claude-config/hooks/pre-write-secrets-scan.ps1` / `.sh` | On `PreToolUse` Write/Edit, deny if written content matches a live-secret pattern. |
| `claude-config/hooks/pre-bash-github-identity.ps1` / `.sh` | On `PreToolUse` Bash, block `gh auth switch`; warn on bare `github.com` push origins. |
| `claude-config/settings.windows.json` / `settings.mac.json` | Wire all five hooks into their events. |
| `README.md` | Document the four new hooks + ledger location. |

**Ledger contract** (the interface between logger and gate): file `~/.claude/sessions/log.md`. Lines:
- Session start: `[<id8>] >>> session started`
- State-changing tool call: `[<id8>] -> <ToolName> <brief>`
where `<id8>` is the first 8 chars of `session_id`. The gate counts only `[<id8>] -> ` lines. High-water mark per session: `~/.claude/sessions/<id8>.verified` (an integer count already gated). The ledger lives in the user's `~/.claude` (not in the repo), so no repo `.gitignore` entry is needed.

---

## Task 1: Session activity logger (start + toolcall)

**Files:**
- Create: `claude-config/hooks/session-log-start.ps1`
- Create: `claude-config/hooks/session-log-start.sh`
- Create: `claude-config/hooks/session-log-toolcall.ps1`
- Create: `claude-config/hooks/session-log-toolcall.sh`

- [ ] **Step 1: Write `session-log-start.ps1`**

```powershell
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
```

- [ ] **Step 2: Write `session-log-start.sh`**

```bash
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
```

- [ ] **Step 3: Write `session-log-toolcall.ps1`**

```powershell
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
```

- [ ] **Step 4: Write `session-log-toolcall.sh`**

```bash
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
        if echo "$cmd" | grep -Eq 'git[[:space:]]+(commit|push|add|merge|rebase|reset|tag|revert)|(^|[[:space:];&|])(rm|mv|cp|mkdir|tee|chmod|chown)[[:space:]]|>>|npm[[:space:]]+(publish|install)|pip[[:space:]]+install|deploy|wrangler[[:space:]]+(deploy|publish)|docker[[:space:]]+(build|push|run)|gh[[:space:]]+(release|pr|issue)[[:space:]]'; then
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
```

- [ ] **Step 5: Smoke-test the logger (edit + read-only + mutating-bash cases)**

Run (Windows):
```powershell
'{"session_id":"abcd1234ef","tool_name":"Write","tool_input":{"file_path":"x.txt"}}' | powershell -File claude-config/hooks/session-log-toolcall.ps1; echo "exit=$LASTEXITCODE"
'{"session_id":"abcd1234ef","tool_name":"Bash","tool_input":{"command":"ls -la"}}' | powershell -File claude-config/hooks/session-log-toolcall.ps1; echo "exit=$LASTEXITCODE"
'{"session_id":"abcd1234ef","tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | powershell -File claude-config/hooks/session-log-toolcall.ps1; echo "exit=$LASTEXITCODE"
Get-Content "$env:USERPROFILE\.claude\sessions\log.md" -Tail 5
```
Expected: every call `exit=0`. The ledger tail shows a `-> Write x.txt` line and a `-> Bash git commit -m x` line, but **no** line for `ls -la` (read-only Bash is not logged).

- [ ] **Step 6: Commit**

```bash
git add claude-config/hooks/session-log-start.ps1 claude-config/hooks/session-log-start.sh claude-config/hooks/session-log-toolcall.ps1 claude-config/hooks/session-log-toolcall.sh
git commit -m "feat(hooks): cross-session activity ledger (start + toolcall loggers)"
```

---

## Task 2: Verification-before-completion gate (Stop)

**Files:**
- Create: `claude-config/hooks/stop-verify-gate.ps1`
- Create: `claude-config/hooks/stop-verify-gate.sh`

- [ ] **Step 1: Write `stop-verify-gate.ps1`**

```powershell
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
```

- [ ] **Step 2: Write `stop-verify-gate.sh`**

```bash
#!/usr/bin/env bash
# Hook: Stop - verification gate against false "completed" claims.
# Mac/Linux version of stop-verify-gate.ps1. Reads the ledger written by
# session-log-toolcall.sh. Fail-open. Bypass: CLAUDE_SKIP_VERIFY_GATE=1
set -uo pipefail
[ "${CLAUDE_SKIP_VERIFY_GATE:-}" = "1" ] && exit 0
input_json=$(cat)
[ -z "$input_json" ] && exit 0
active=$(echo "$input_json" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0
id=$(echo "$input_json" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$id" ] && exit 0
id8=${id:0:8}
dir="$HOME/.claude/sessions"
log="$dir/log.md"
[ -f "$log" ] || exit 0

mapfile -t mine < <(grep -F "[$id8] -> " "$log" 2>/dev/null)
total=${#mine[@]}
[ "$total" -eq 0 ] && exit 0

mark="$dir/$id8.verified"
prior=0
[ -f "$mark" ] && prior=$(tr -dc '0-9' < "$mark" 2>/dev/null) && prior=${prior:-0}
[ "$total" -le "$prior" ] && exit 0

start=$prior
[ $((total - prior)) -gt 12 ] && start=$((total - 12))
action_list=""
for ((i=start; i<total; i++)); do action_list+="  ${mine[$i]}"$'\n'; done
echo "$total" > "$mark" 2>/dev/null || true

reason="VERIFICATION GATE - do not end the turn claiming work is complete until you have verified it against fresh reads. A successful tool call (HTTP 200 / no error) is NOT proof of completion - confirm the resulting STATE.

State-changing actions this turn:
${action_list}
For each, before saying done / fixed / sent / validated:
- External service writes (CRM / database / API record) -> re-fetch the record; confirm the field or status actually changed.
- Sends (email / chat / SMS) -> confirm it left as SENT. If it was only staged as a draft, say \"drafted, not sent\" - never claim sent.
- File edits -> re-read the changed region; if it was a fix, show the check / test output that proves it.
- git / build / deploy -> show the actual output (commit hash, deploy id, push result), not an assumption.

State the evidence first, then the claim. If you have ALREADY shown this evidence in your reply, briefly restate the proof and stop."

jq -n --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
```

- [ ] **Step 3: Smoke-test the gate fires then de-dupes**

Run (Windows):
```powershell
$j = '{"session_id":"smoke999xy","tool_name":"Write","tool_input":{"file_path":"a.txt"}}'
$j | powershell -File claude-config/hooks/session-log-toolcall.ps1   # log one action
'{"session_id":"smoke999xy","stop_hook_active":false}' | powershell -File claude-config/hooks/stop-verify-gate.ps1   # 1st stop
echo "---second stop (should be silent)---"
'{"session_id":"smoke999xy","stop_hook_active":false}' | powershell -File claude-config/hooks/stop-verify-gate.ps1   # 2nd stop
```
Expected: first Stop prints a JSON object containing `"decision":"block"` and the `a.txt` action; the second Stop prints **nothing** (already gated — high-water mark advanced). Clean up: `Remove-Item "$env:USERPROFILE\.claude\sessions\smoke999xy.verified" -ErrorAction SilentlyContinue`.

- [ ] **Step 4: Commit**

```bash
git add claude-config/hooks/stop-verify-gate.ps1 claude-config/hooks/stop-verify-gate.sh
git commit -m "feat(hooks): verification-before-completion Stop gate (reads activity ledger)"
```

---

## Task 3: Secrets-write scanner (PreToolUse Write/Edit)

**Files:**
- Create: `claude-config/hooks/pre-write-secrets-scan.ps1`
- Create: `claude-config/hooks/pre-write-secrets-scan.sh`

- [ ] **Step 1: Write `pre-write-secrets-scan.ps1`**

```powershell
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
```

- [ ] **Step 2: Write `pre-write-secrets-scan.sh`**

```bash
#!/usr/bin/env bash
# Hook: PreToolUse / Write|Edit - block writing live secrets into any file.
# Mac/Linux version of pre-write-secrets-scan.ps1. Fail-open. ASCII-only.
set -uo pipefail
input_json=$(cat)
[ -z "$input_json" ] && exit 0
blob=$(echo "$input_json" | jq -r '[.tool_input.content, .tool_input.new_string, (.tool_input.edits[]?.new_string)] | map(select(. != null)) | join("\n")' 2>/dev/null)
[ -z "$blob" ] && exit 0

declare -a hits=()
add() { echo "$blob" | grep -Eq "$2" && hits+=("$1"); }
add 'Private key block'       '-----BEGIN (RSA |EC |OPENSSH |PGP |DSA )?PRIVATE KEY-----'
add 'AWS access key id'       'AKIA[0-9A-Z]{16}'
add 'Anthropic API key'       'sk-ant-[A-Za-z0-9_-]{24,}'
add 'OpenAI-style key'        'sk-[A-Za-z0-9]{32,}'
add 'GitHub token'            '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}'
add 'GitHub fine-grained PAT' 'github_pat_[A-Za-z0-9_]{50,}'
add 'Slack token'             'xox[baprs]-[A-Za-z0-9-]{12,}'
add 'Google API key'          'AIza[0-9A-Za-z_-]{35}'
add 'Stripe live key'         '(sk|rk)_live_[0-9a-zA-Z]{24,}'
[ ${#hits[@]} -eq 0 ] && exit 0

fp=$(echo "$input_json" | jq -r '.tool_input.file_path // "the target file"' 2>/dev/null)
joined=$(IFS=', '; echo "${hits[*]}")
reason="BLOCKED by secrets-scan: content being written to '$fp' looks like a live secret ($joined). Never write real credentials into a file. Put it in an environment variable or a gitignored .env / your secret manager and reference it via the environment. If this is a redacted placeholder, rephrase so it does not match a real-key shape."
jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$r}}'
exit 0
```

- [ ] **Step 3: Smoke-test (deny on a key shape, allow on normal text)**

Build the test key at runtime so this plan file never itself contains a contiguous real-key shape (the scanner would otherwise deny writing this very plan):

Run (Windows):
```powershell
$fake = 'AKIA' + 'IOSFODNN7EXAMPLE'   # split intentionally; recombined only at runtime
$body = '{"tool_input":{"file_path":"x.env","content":"TOKEN=' + $fake + '"}}'
$body | powershell -File claude-config/hooks/pre-write-secrets-scan.ps1
echo "---should be silent (no secret)---"
'{"tool_input":{"file_path":"readme.md","content":"hello world, no secrets here"}}' | powershell -File claude-config/hooks/pre-write-secrets-scan.ps1
```
Expected: the first prints JSON with `"permissionDecision":"deny"` and `AWS access key id`; the second prints nothing.

- [ ] **Step 4: Commit**

```bash
git add claude-config/hooks/pre-write-secrets-scan.ps1 claude-config/hooks/pre-write-secrets-scan.sh
git commit -m "feat(hooks): secrets-write scanner denies live-credential shapes"
```

---

## Task 4: GitHub identity guard (PreToolUse Bash)

**Files:**
- Create: `claude-config/hooks/pre-bash-github-identity.ps1`
- Create: `claude-config/hooks/pre-bash-github-identity.sh`

- [ ] **Step 1: Write `pre-bash-github-identity.ps1`**

```powershell
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
```

- [ ] **Step 2: Write `pre-bash-github-identity.sh`**

```bash
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
```

- [ ] **Step 3: Smoke-test (block switch, ignore a mere mention)**

Run (Windows):
```powershell
'{"tool_input":{"command":"gh auth switch --user someone"}}' | powershell -File claude-config/hooks/pre-bash-github-identity.ps1
echo "---should be silent (mention inside quotes)---"
'{"tool_input":{"command":"rg \"gh auth switch\" ."}}' | powershell -File claude-config/hooks/pre-bash-github-identity.ps1
```
Expected: the first prints JSON with `"permissionDecision":"deny"`; the second prints nothing (the command is a quoted search string, not an invocation).

- [ ] **Step 4: Commit**

```bash
git add claude-config/hooks/pre-bash-github-identity.ps1 claude-config/hooks/pre-bash-github-identity.sh
git commit -m "feat(hooks): account-agnostic GitHub identity guard"
```

---

## Task 5: Wire hooks into settings + document them

**Files:**
- Modify: `claude-config/settings.windows.json`
- Modify: `claude-config/settings.mac.json`
- Modify: `README.md`

- [ ] **Step 1: Read both settings files to learn the existing hook-wiring shape**

Run: `cat claude-config/settings.windows.json` and `cat claude-config/settings.mac.json`. Note the existing `hooks` object structure (event name -> array of `{matcher, hooks:[{type:"command", command:"..."}]}`). Mirror it exactly; only the `command` path and event differ per OS file (Windows invokes `.ps1` via PowerShell, Mac invokes `.sh` via bash, following whatever the existing entries already do).

- [ ] **Step 2: Add the five hook registrations to `settings.windows.json`**

Add entries under the matching events, following the existing entries' exact command-invocation style. The five registrations are:
- `SessionStart` -> `session-log-start.ps1`
- `PreToolUse` matcher `Write|Edit|MultiEdit|NotebookEdit|Bash` -> `session-log-toolcall.ps1`
- `PreToolUse` matcher `Write|Edit|MultiEdit` -> `pre-write-secrets-scan.ps1`
- `PreToolUse` matcher `Bash` -> `pre-bash-github-identity.ps1`
- `Stop` -> `stop-verify-gate.ps1`

If a `PreToolUse` matcher already exists, append the new hook to that matcher's `hooks` array rather than duplicating the matcher.

- [ ] **Step 3: Add the same five to `settings.mac.json`** pointing at the `.sh` files, using that file's existing bash-invocation style.

- [ ] **Step 4: Validate both settings files are valid JSON**

Run:
```bash
jq empty claude-config/settings.windows.json && echo "windows OK"
jq empty claude-config/settings.mac.json && echo "mac OK"
```
Expected: both print `OK`. (No error from `jq empty` means valid JSON.)

- [ ] **Step 5: Document the four hooks in `README.md`**

In the "What you get" section, update the hook-stack bullet to reflect the new always-active hooks. Add this block near the existing hook documentation:

```markdown
**Always-active hooks (no customization needed):**
- `session-log-start` / `session-log-toolcall` - write a local cross-session activity ledger to `~/.claude/sessions/log.md` (so concurrent sessions see recent work, and the verification gate has data).
- `stop-verify-gate` - on any turn that changed state (edits, mutating shell, git/deploy), blocks the turn once and requires verifying the result against fresh reads before claiming done. Bypass with `CLAUDE_SKIP_VERIFY_GATE=1`.
- `pre-write-secrets-scan` - denies a Write/Edit whose content matches a live-credential shape (AWS/GitHub/Slack/Stripe/etc.).
- `pre-bash-github-identity` - blocks `gh auth switch` and warns on bare `github.com` push origins; account-agnostic. Bypass with `CLAUDE_SKIP_GH_IDENTITY=1`.

The ledger lives in `~/.claude/sessions/` (your home dir, not this repo) - nothing is committed.
```

- [ ] **Step 6: Commit**

```bash
git add claude-config/settings.windows.json claude-config/settings.mac.json README.md
git commit -m "feat(hooks): wire active hooks into settings + document them"
```

---

## Task 6: Sanitization gate + full smoke battery

**Files:** none created — this is the release gate for the sub-plan.

- [ ] **Step 1: Run the sanitization denylist over everything added in this plan**

Run (substitute `<base>` with the commit before this plan's first commit, e.g. the current `HEAD` before Task 1):
```bash
git diff <base>..HEAD --name-only | grep -E 'hooks/|settings|README' | while read f; do echo "== $f =="; grep -niE "a/?c authority|acauthority|kjricciardi|stoopkid|ricciardi|housecall|\bHCP\b|\bQBO\b|quickbooks|trello|callrail|\bGHL\b|sunsama|bamboo|cloudflare dashboard|STOOP|TL-DPS" "$f" && echo "!! LEAK !!" || true; done; echo "scan done"
```
Expected: no `!! LEAK !!` line. If anything hits, sanitize it and amend the relevant commit before proceeding.

- [ ] **Step 2: Re-run every hook's smoke test from Tasks 1-4 in one batch** to confirm none hard-errors and each behaves as specified. Confirm all exit codes are 0 and the block/deny/silent behaviors match the per-task "Expected" notes.

- [ ] **Step 3: Confirm cross-platform parity** — every new hook exists as BOTH `.ps1` and `.sh`:

```bash
for h in session-log-start session-log-toolcall stop-verify-gate pre-write-secrets-scan pre-bash-github-identity; do
  for ext in ps1 sh; do [ -f "claude-config/hooks/$h.$ext" ] && echo "ok $h.$ext" || echo "MISSING $h.$ext"; done
done
```
Expected: 10 `ok` lines, no `MISSING`.

- [ ] **Step 4: Final commit (only if sanitization fixes were made in Step 1)**

```bash
git add -- claude-config/hooks README.md claude-config/settings.windows.json claude-config/settings.mac.json
git commit -m "chore(hooks): sanitization pass + smoke battery green for active-hooks bundle"
```

---

## Self-review notes (author)

- **Spec coverage:** This sub-plan implements the spec's default-active Phase-1 hooks: `session-activity-logger`, `stop-verify-gate`, `pre-write-secrets-scan`, `pre-bash-github-identity`. Deferred to later sub-plans: `stop-board-gate` (.template) + rules files (1b), `best-practices.md` + `workflows.md` (1c), `core-rules.md.template` upgrade + README curriculum links (1d), and Phase 2 `GUIDE.md`.
- **Sanitization:** Task 6 gate enforces zero proper-noun hits; all reason texts use generic service/account language. Note: the AWS test fixture in Task 3 is split (`'AKIA' + 'IOSFODNN7...'`) so this plan file itself does not match the scanner.
- **Type/interface consistency:** the ledger line format `[<id8>] -> <Tool> <brief>` written by `session-log-toolcall` matches the reader grep `"[<id8>] -> "` in `stop-verify-gate`, in both `.ps1` and `.sh`. Bypass env vars (`CLAUDE_SKIP_VERIFY_GATE`, `CLAUDE_SKIP_GH_IDENTITY`) are named consistently between each hook and its README documentation.
```
