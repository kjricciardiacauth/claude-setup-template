# Phase 1b: Rules + Board Gate (opt-in) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the generalized GitHub-Projects + identity discipline rule, a registry template, a Cloudflare Workers rule, and an opt-in `stop-board-gate` hook (ships as `.template`, inert until configured) — all project-agnostic and sanitized.

**Architecture:** Two reference rules under `claude-config/rules/` (one always-on, one path-scoped), a JSON registry template, and a Stop hook that reads the activity ledger (from Phase 1a) plus `~/.claude/rules/github-projects.json` to decide whether a turn shipped tracked work without a board update. The board gate is **opt-in**: it stays inert unless the registry exists and lists a project. The 1a logger is extended one line so board updates done via `gh project` are visible to the gate.

**Tech Stack:** Markdown rules, JSON, PowerShell + bash hooks (`jq`), Claude Code `Stop`/`PreToolUse` events.

---

## File Structure

| File | Responsibility |
|---|---|
| `claude-config/rules/github-rules.md` | Board-as-source-of-truth + identity discipline (always-on reference rule). |
| `claude-config/rules/github-projects.json.template` | Registry schema with placeholder example entry. |
| `claude-config/rules/workers.md` | Cloudflare Workers deploy conventions (path-scoped to worker files). |
| `claude-config/hooks/stop-board-gate.ps1.template` / `.sh.template` | Opt-in Stop hook: block if a turn shipped tracked-repo work without a board update. |
| `claude-config/hooks/session-log-toolcall.ps1` / `.sh` | MODIFY: add `gh project` to the mutation heuristic so board updates are logged. |
| `claude-config/settings.windows.json` / `settings.mac.json` | Register `stop-board-gate` on `Stop` (no-ops until the `.template` is renamed). |
| `README.md` | Document the rules + add the new `.template` files to "What to customize". |

---

## Task 1: github-rules.md rule

**Files:** Create `claude-config/rules/github-rules.md`

- [ ] **Step 1: Write the file** (ASCII-only; follow the existing `git.md` style — no frontmatter, always-on reference)

```markdown
# GitHub Projects + Identity Discipline

> Opt-in. Applies only to repos listed in `github-projects.json` (the registry). If you don't use GitHub
> Projects, ignore this file and leave `stop-board-gate` as a `.template`. Enforced by `stop-board-gate`
> (board) + `pre-bash-github-identity` (identity).

## The registry
- `claude-config/rules/github-projects.json` lists each repo that uses a GitHub Project, with its board number,
  owner, account, and path hints. **Adding a project = one entry** and the board gate picks it up automatically.
- Copy `github-projects.json.template` to `github-projects.json` and fill in your project(s).

## Board is the source of truth (any registered project)
- Open work lives on the repo's GitHub Project (number per the registry), not a scattered markdown TODO list.

## Card lifecycle (HARD)
- **Pick up** a card -> Status **In Progress**.
- **Finish** -> comment the evidence + **close with the commit hash** (`gh issue close <n> --comment "Fixed in <hash>"`) + Status **Done**.
- **New follow-up work** -> **create a card** rather than letting it vanish.
- Shipping work to a registered repo (commit / push / release / deploy) WITHOUT a board update -> `stop-board-gate` blocks the turn.

## Identity (HARD - all GitHub work)
- Remotes embed the account (`https://<account>@github.com/...`); a bare `https://github.com/...` origin is the bug.
- **Never `gh auth switch`** - it flips the machine-global active account and races concurrent sessions.
- The gh `project` scope must be present: `gh auth refresh -s project`.

## Process
- **Substantive** work runs the full workflow (brainstorm -> plan -> execute -> finish); trivial edits don't, but
  name the step you skipped. Verify against fresh reads before claiming completion, always.
```

- [ ] **Step 2: Commit**

```bash
git add claude-config/rules/github-rules.md
git commit -m "feat(rules): generalized GitHub Projects + identity discipline rule"
```

---

## Task 2: github-projects.json.template registry

**Files:** Create `claude-config/rules/github-projects.json.template`

- [ ] **Step 1: Write the file** (valid JSON, placeholder values only — NO real accounts)

```json
{
  "projects": [
    {
      "repo": "your-username/your-repo",
      "owner": "your-username",
      "ownerType": "user",
      "projectNumber": 1,
      "account": "your-username",
      "pathHints": ["your-repo"],
      "relatedRepos": []
    }
  ]
}
```

- [ ] **Step 2: Validate it is valid JSON**

Run: `jq empty claude-config/rules/github-projects.json.template && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add claude-config/rules/github-projects.json.template
git commit -m "feat(rules): github-projects.json registry template (placeholder)"
```

---

## Task 3: workers.md rule

**Files:** Create `claude-config/rules/workers.md`

- [ ] **Step 1: Write the file** (ASCII-only; keep the `paths:` frontmatter so it loads only for worker files)

```markdown
---
paths:
  - "workers/**/*.js"
  - "workers/**/*.toml"
  - "wrangler.toml"
---

# Cloudflare Workers Rules

## Deployment model
If your workers are git-connected (Cloudflare Workers Builds), pushing the default branch auto-deploys - no
manual paste. Otherwise deploy with `wrangler deploy`.

- **Bindings** (KV, D1, R2, Durable Objects, queues) MUST be declared in `wrangler.toml` - wrangler wipes any
  dashboard-only bindings on deploy. Add the binding to `wrangler.toml` BEFORE you push/deploy.
- **Secrets** stay in the Cloudflare dashboard (or `wrangler secret put`) - wrangler never wipes secrets. Never
  commit them to a file.
- **Auth:** let `wrangler` resolve the account from your OAuth login (`wrangler login`). Don't hardcode an
  account id / `CLOUDFLARE_ACCOUNT_ID` unless you specifically need to.

## Live-consumer safety (HARD)
- A deploy restarts the worker (and any Durable Objects) - don't deploy while live clients are mid-session if a
  reconnect blip matters.
- Keep every deploy backward-compatible: a worker often serves a mix of client versions at once. Make changes
  additive / capability-gated; never assume the matching client already shipped.

## Your worker registry (optional)
Keep a table here of each worker, its Cloudflare name, and the bindings its `wrangler.toml` must include - so the
pre-push check is simply "does wrangler.toml include every binding this worker needs?"
```

- [ ] **Step 2: Commit**

```bash
git add claude-config/rules/workers.md
git commit -m "feat(rules): generalized Cloudflare Workers deploy conventions"
```

---

## Task 4: stop-board-gate hook (opt-in) + logger patch

**Files:**
- Create: `claude-config/hooks/stop-board-gate.ps1.template`
- Create: `claude-config/hooks/stop-board-gate.sh.template`
- Modify: `claude-config/hooks/session-log-toolcall.ps1` (add `gh project` to mutation heuristic)
- Modify: `claude-config/hooks/session-log-toolcall.sh` (same)

- [ ] **Step 1: Patch `session-log-toolcall.ps1`** so `gh project ...` is logged (needed for the board gate to see `gh project` board updates). Find the `$mut` regex line and change the trailing `gh\s+(release|pr|issue)\s` to `gh\s+(release|pr|issue|project)\s`. The full updated line:

```powershell
        $mut = 'git\s+(commit|push|add|merge|rebase|reset|tag|revert)|(^|[\s;&|])(rm|mv|cp|mkdir|tee|chmod|chown)\s|>>|(^|[\s;&|])[^|]*>|npm\s+(publish|install)|pip\s+install|deploy|wrangler\s+(deploy|publish)|docker\s+(build|push|run)|gh\s+(release|pr|issue|project)\s'
```

- [ ] **Step 2: Patch `session-log-toolcall.sh`** identically — change `gh[[:space:]]+(release|pr|issue)[[:space:]]` to `gh[[:space:]]+(release|pr|issue|project)[[:space:]]`. The full updated `grep -Eq` pattern:

```bash
        if echo "$cmd" | grep -Eq 'git[[:space:]]+(commit|push|add|merge|rebase|reset|tag|revert)|(^|[[:space:];&|])(rm|mv|cp|mkdir|tee|chmod|chown)[[:space:]]|>>|npm[[:space:]]+(publish|install)|pip[[:space:]]+install|deploy|wrangler[[:space:]]+(deploy|publish)|docker[[:space:]]+(build|push|run)|gh[[:space:]]+(release|pr|issue|project)[[:space:]]'; then
```

- [ ] **Step 3: Write `stop-board-gate.ps1.template`** (registry-driven; inert without a registry; ASCII-only)

```powershell
# Hook: Stop - board-update gate for tracked GitHub Projects work.
# If this turn SHIPPED work to a tracked repo (git commit/push, gh release, wrangler deploy with a registry
# signal) but made NO board update (no gh project / gh issue op in the same turn), block so the turn updates the
# board (or states why no card applies). Reads the activity ledger written by session-log-toolcall.
# Opt-in: inert unless ~/.claude/rules/github-projects.json exists and lists a project.
# Rename this file to stop-board-gate.ps1 to activate. Bypass: $env:CLAUDE_SKIP_BOARD_GATE = "1"
if ($env:CLAUDE_SKIP_BOARD_GATE -eq "1") { exit 0 }
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

    $markFile = "$sessionDir\$id8.boardgate"
    $prior = 0
    if (Test-Path $markFile) {
        $raw = (Get-Content $markFile -Raw -ErrorAction SilentlyContinue).Trim()
        [int]::TryParse($raw, [ref]$prior) | Out-Null
    }
    if ($total -le $prior) { exit 0 }
    $new = $mine[$prior..($total - 1)]

    $regPath = "$env:USERPROFILE\.claude\rules\github-projects.json"
    if (-not (Test-Path $regPath)) { Set-Content -Path $markFile -Value "$total" -EA SilentlyContinue; exit 0 }
    try { $reg = Get-Content $regPath -Raw -EA Stop | ConvertFrom-Json } catch { exit 0 }
    $signals = @()
    foreach ($p in $reg.projects) {
        if ($p.repo) { $signals += [regex]::Escape($p.repo) }
        foreach ($r in $p.relatedRepos) { $signals += [regex]::Escape($r) }
        foreach ($h in $p.pathHints) { $signals += [regex]::Escape($h) }
    }
    if ($signals.Count -eq 0) { Set-Content -Path $markFile -Value "$total" -EA SilentlyContinue; exit 0 }
    $sigRegex = ($signals -join '|')

    $tracked = $new | Where-Object { $_ -match $sigRegex }
    if (-not $tracked) { Set-Content -Path $markFile -Value "$total" -ErrorAction SilentlyContinue; exit 0 }

    $shipped = $new | Where-Object {
        ($_ -match '-> Bash\s+.*(git (commit|push)|gh release create|wrangler deploy)') -and
        ($_ -match $sigRegex)
    }
    if (-not $shipped) {
        $anyShip = $new | Where-Object { $_ -match '-> Bash\s+.*(git (commit|push)|gh release create|wrangler deploy)' }
        if ($anyShip) { $shipped = $anyShip }
    }
    if (-not $shipped) { Set-Content -Path $markFile -Value "$total" -ErrorAction SilentlyContinue; exit 0 }

    $boardOp = $new | Where-Object { $_ -match '-> Bash\s+.*(gh project|gh issue (close|create|comment|edit))' }

    Set-Content -Path $markFile -Value "$total" -ErrorAction SilentlyContinue
    if ($boardOp) { exit 0 }

    $shipList = ($shipped | Select-Object -First 8 | ForEach-Object { "  $_" }) -join "`n"
    $reason = @"
BOARD GATE - this turn shipped work to a tracked GitHub Projects repo but did not update its board.

Shipped this turn:
$shipList

Before ending: move/close the matching card with the commit hash (e.g.
  gh issue close <n> --repo <owner>/<repo> --comment "Fixed in <hash>"
  gh project item-edit --id <item> --project-id <proj> --field-id <Status> --single-select-option-id <Done>),
OR create a card for new work, OR state explicitly why no card applies. Then stop.
If you ALREADY updated the board this turn, say which card and stop.
"@
    @{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress -Depth 5 | Write-Output
} catch { exit 0 }
```

- [ ] **Step 4: Write `stop-board-gate.sh.template`** (bash port; ASCII-only)

```bash
#!/usr/bin/env bash
# Hook: Stop - board-update gate for tracked GitHub Projects work. (Mac/Linux)
# Opt-in: inert unless ~/.claude/rules/github-projects.json exists and lists a project.
# Rename this file to stop-board-gate.sh to activate. Bypass: CLAUDE_SKIP_BOARD_GATE=1
set -uo pipefail
[ "${CLAUDE_SKIP_BOARD_GATE:-}" = "1" ] && exit 0
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

mark="$dir/$id8.boardgate"
prior=0
[ -f "$mark" ] && prior=$(tr -dc '0-9' < "$mark" 2>/dev/null) && prior=${prior:-0}
[ "$total" -le "$prior" ] && exit 0
new=("${mine[@]:$prior}")

reg="$HOME/.claude/rules/github-projects.json"
_mark_exit() { echo "$total" > "$mark" 2>/dev/null || true; exit 0; }
[ -f "$reg" ] || _mark_exit

signals=$(jq -r '[.projects[]? | .repo, (.relatedRepos[]?), (.pathHints[]?)] | map(select(. != null and . != "")) | unique | join("|")' "$reg" 2>/dev/null)
[ -z "$signals" ] && _mark_exit

newblob=$(printf '%s\n' "${new[@]}")
echo "$newblob" | grep -Eq "$signals" || _mark_exit

shipped=$(echo "$newblob" | grep -E -- 'Bash[[:space:]].*(git (commit|push)|gh release create|wrangler deploy)' || true)
[ -z "$shipped" ] && _mark_exit

boardop=$(echo "$newblob" | grep -E -- 'Bash[[:space:]].*(gh project|gh issue (close|create|comment|edit))' || true)

echo "$total" > "$mark" 2>/dev/null || true
[ -n "$boardop" ] && exit 0

shiplist=$(echo "$shipped" | head -8 | sed 's/^/  /')
reason="BOARD GATE - this turn shipped work to a tracked GitHub Projects repo but did not update its board.

Shipped this turn:
$shiplist

Before ending: move/close the matching card with the commit hash (e.g.
  gh issue close <n> --repo <owner>/<repo> --comment \"Fixed in <hash>\"
  gh project item-edit --id <item> --project-id <proj> --field-id <Status> --single-select-option-id <Done>),
OR create a card for new work, OR state explicitly why no card applies. Then stop.
If you ALREADY updated the board this turn, say which card and stop."

jq -n --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
```

- [ ] **Step 5: Smoke-test the logger patch + board gate**

The gate ships as `.template` (inert). To TEST it, copy it to a temp `.ps1` and drive it with a fake registry + ledger:
```
# 1) logger patch: gh project is now logged
echo '{"session_id":"bg123456","tool_name":"Bash","tool_input":{"command":"gh project item-edit --id x"}}' | powershell -File claude-config/hooks/session-log-toolcall.ps1
powershell -Command "Get-Content \"$env:USERPROFILE\.claude\sessions\log.md\" -Tail 1"
# expect a line: [bg123456] -> Bash gh project item-edit --id x

# 2) board gate: set up a fake registry + ledger, run the template as a .ps1
$reg = "$env:USERPROFILE\.claude\rules\github-projects.json"
$bak = "$reg.smokebak"
if (Test-Path $reg) { Move-Item $reg $bak -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $reg) | Out-Null
'{"projects":[{"repo":"acme/widget","pathHints":["widget"],"relatedRepos":[]}]}' | Set-Content $reg
Copy-Item claude-config/hooks/stop-board-gate.ps1.template "$env:TEMP\sbg.ps1" -Force
# ledger: a shipped line touching the tracked repo, NO board op
$sd = "$env:USERPROFILE\.claude\sessions"; Set-Content "$sd\log.md" "[bgtest01] -> Bash git commit -m widget fix"
Remove-Item "$sd\bgtest01.boardgate" -ErrorAction SilentlyContinue
echo "--- expect BLOCK (shipped tracked work, no board op) ---"
echo '{"session_id":"bgtest01","stop_hook_active":false}' | powershell -File "$env:TEMP\sbg.ps1"
# now add a board op to the same turn
Add-Content "$sd\log.md" "[bgtest01] -> Bash gh issue close 5 --comment done"
Remove-Item "$sd\bgtest01.boardgate" -ErrorAction SilentlyContinue
echo "--- expect SILENT (board updated) ---"
echo '{"session_id":"bgtest01","stop_hook_active":false}' | powershell -File "$env:TEMP\sbg.ps1"
# cleanup
Remove-Item "$reg" -Force; if (Test-Path $bak) { Move-Item $bak $reg -Force }
Remove-Item "$sd\bgtest01.boardgate","$env:TEMP\sbg.ps1" -ErrorAction SilentlyContinue
```
Expected: step 1 logs the `gh project` line; the first gate run prints JSON with `"decision":"block"`; the second prints NOTHING. If different, fix to match and re-test. (Be careful to restore any pre-existing registry from the `.smokebak`.)

- [ ] **Step 6: Commit**

```bash
git add claude-config/hooks/stop-board-gate.ps1.template claude-config/hooks/stop-board-gate.sh.template claude-config/hooks/session-log-toolcall.ps1 claude-config/hooks/session-log-toolcall.sh
git commit -m "feat(hooks): opt-in board-update gate (.template) + log gh project ops"
```

---

## Task 5: Wire board gate into settings + document rules

**Files:** Modify `claude-config/settings.windows.json`, `claude-config/settings.mac.json`, `README.md`

- [ ] **Step 1: Register `stop-board-gate` on the `Stop` event in BOTH settings files**, following the exact same structure used for `stop-verify-gate` in Phase 1a (append to the existing `Stop` array). Windows points at `stop-board-gate.ps1`, Mac at `stop-board-gate.sh`. NOTE: the file on disk is `.template`, so the hook no-ops silently until the user renames it — this is the intended template convention (settings reference all hooks; missing scripts are harmless).

- [ ] **Step 2: Validate JSON**

```bash
jq empty claude-config/settings.windows.json && echo "windows OK"
jq empty claude-config/settings.mac.json && echo "mac OK"
```
Expected: both `OK`.

- [ ] **Step 3: Update `README.md` "What to customize after install" table** — add rows (ASCII-only):

```markdown
| `claude-config/rules/github-projects.json.template` -> `github-projects.json` | Your GitHub Projects repos (board number, owner, account) - enables the board gate |
| `claude-config/hooks/stop-board-gate.{ps1\|sh}.template` -> drop `.template` | Activate the board-update gate (needs the registry above) |
```

Also add a short bullet near the hook docs noting the opt-in rules:
```markdown
**Opt-in (GitHub Projects users):** `claude-config/rules/github-rules.md` documents board + identity discipline; fill in `github-projects.json` and rename `stop-board-gate.{ps1|sh}.template` to enable a Stop gate that blocks shipping to a tracked repo without a board update. `claude-config/rules/workers.md` adds Cloudflare Workers deploy conventions (loads only when worker files are active).
```
If the README states a hook count, update it to stay accurate; keep the change minimal.

- [ ] **Step 4: Commit**

```bash
git add claude-config/settings.windows.json claude-config/settings.mac.json README.md
git commit -m "feat(rules): wire board gate into settings + document rules in README"
```

---

## Task 6: Sanitization gate + parity + smoke battery

**Files:** none created — release gate.

- [ ] **Step 1: Sanitization denylist** over everything added/changed in this plan (rules + new hooks + settings + README). Run, substituting `<base>` with the commit before Task 1:
```bash
git diff <base>..HEAD --name-only | grep -E 'rules/|hooks/|settings|README' | while read f; do echo "== $f =="; grep -niE "a/?c authority|acauthority|kjricciardi|stoopkid|ricciardi|housecall|\bHCP\b|\bQBO\b|quickbooks|trello|callrail|\bGHL\b|sunsama|bamboo|\bSTOOP\b|TL-DPS|oncallair|round-mode|icy-mouse" "$f" && echo "!! LEAK !!" || true; done; echo "scan done"
```
Expected: no `!! LEAK !!`. (The repo's own clone URL in README is the legitimate template address, not a leak — if it appears, it is acceptable.)

- [ ] **Step 2: ASCII check** on all new/changed files:
```bash
grep -rPn "[^\x00-\x7F]" claude-config/rules/github-rules.md claude-config/rules/workers.md claude-config/rules/github-projects.json.template claude-config/hooks/stop-board-gate.ps1.template claude-config/hooks/stop-board-gate.sh.template && echo "!! NON-ASCII !!" || echo "ASCII-clean"
```
Expected: `ASCII-clean`.

- [ ] **Step 3: Parity** — board-gate ships as both `.ps1.template` and `.sh.template`:
```bash
for ext in ps1 sh; do [ -f "claude-config/hooks/stop-board-gate.$ext.template" ] && echo "ok stop-board-gate.$ext.template" || echo "MISSING"; done
```
Expected: 2 `ok`.

- [ ] **Step 4: Regression** — confirm the Phase 1a hooks still behave (logger patch didn't break them). Re-run the 1a consolidated smoke battery (logger Write exit 0, verify-gate block, secrets deny, identity deny) and confirm a read-only Bash is STILL not logged.

- [ ] **Step 5: Final commit (only if fixes were made in Steps 1-2).**

```bash
git add -- claude-config/rules claude-config/hooks claude-config/settings.windows.json claude-config/settings.mac.json README.md
git commit -m "chore(rules): sanitization + parity green for phase 1b"
```

---

## Self-review notes (author)

- **Spec coverage:** implements the spec's Phase-1 `github-rules.md`, `github-projects.json.template`, `workers.md`, and the opt-in `stop-board-gate` (.template). Deferred: `best-practices.md` + `workflows.md` (1c), `core-rules.md.template` upgrade (1d), Phase 2 `GUIDE.md`.
- **Sanitization:** business worker registry, account names, and STOOP/board-number specifics were dropped; the board-gate reason text uses generic `<owner>/<repo>` placeholders; the registry template uses `your-username/your-repo`.
- **Cross-hook consistency:** the board gate detects board updates via `gh project`/`gh issue`; Task 4 patches the 1a logger so `gh project` is logged (otherwise a `gh project`-only update would be invisible to the gate). The `gh issue` path was already logged. Ledger line format and high-water-mark sidecar (`<id8>.boardgate`, distinct from `<id8>.verified`) are consistent with Phase 1a.
- **Opt-in safety:** the gate is inert without `~/.claude/rules/github-projects.json`; it ships as `.template` so it does nothing until the user both populates the registry and renames the file.
```
