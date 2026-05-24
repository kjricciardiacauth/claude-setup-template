# Hooks Sync Pattern - `claude-config/settings.json` + helper scripts across PCs

**Canonical locations:**
- `claude-config/settings.json` - hooks/permissions config (linked to `~/.claude/settings.json`)
- `claude-config/hooks/` - helper PowerShell scripts (junctioned to `~/.claude/hooks/`)

**Active locations:** `~/.claude/settings.json` and `~/.claude/hooks/` (linked/junctioned to the canonical files above)
**Tracked in git:** Yes - both flow to all PCs via `git pull`. `bootstrap.ps1` sets up the link and junction automatically.

## Inline vs helper-script hook commands

For trivial hooks (always-fire reminders), keep the command inline:
```json
"command": "Write-Output '{\"hookSpecificOutput\":{...}}'"
```

For hooks that need to filter on tool input (e.g., fire only when bash command matches a pattern), use a helper script in `claude-config/hooks/`. The `if` field in settings.json (`"if": "Bash(git push*)"`) does not reliably gate execution - hooks fire on every matching tool call regardless of the `if` pattern. Solution: helper script reads stdin JSON, inspects `tool_input.command`, and emits the reminder JSON only when it matches.

Example: `claude-config/hooks/post-bash-git-push.ps1.template` filters PostToolUse Bash to only fire on actual `git push *` commands.

Settings.json then invokes:
```json
"command": "& \"$env:USERPROFILE\\.claude\\hooks\\post-bash-git-push.ps1\""
```

Pattern: read stdin via `[Console]::In.ReadToEnd()`, parse JSON, conditionally emit. Exit cleanly with `exit 0` and no output to suppress the hook for non-matching cases.

## Known limitations

### PowerShell script files must be ASCII-only

PowerShell on Windows defaults to cp1252. Multi-byte UTF-8 characters (em-dashes, smart quotes, etc.) get mojibake'd and break parsing. **Rule: only ASCII punctuation in `.ps1` files.** Comments and strings both. Use `-` instead of em-dash, `"..."` instead of curly quotes.

### `$varName:` is a drive prefix

PowerShell parses `:` in interpolated strings as a drive namespace separator. `"${var}:"` not `"$var:"`.

### `-ErrorAction SilentlyContinue` doesn't suppress terminating errors

Cmdlets that throw terminating errors (e.g., `Set-ExecutionPolicy` when overridden by higher scope) bypass `SilentlyContinue`. Wrap in `try { Cmd -ErrorAction Stop } catch {}` to truly swallow.

### Edit tool validates BEFORE PreToolUse hook fires

The Edit tool's "file must exist" and "must Read first" preconditions short-circuit and prevent PreToolUse hooks from seeing the call. To test a Write|Edit sensitive-path hook:
- **GOOD:** Write to a non-existent path in a sensitive directory (Write doesn't require pre-existence)
- **GOOD:** Read an existing sensitive file, then Edit (now passes pre-checks)
- **BAD:** Edit a non-existent path - tool rejects, hook never fires

The hook IS correctly configured; only its observability is gated by Edit-tool validation.

---

## What this file contains

Default Claude Code session hooks (wired in `claude-config/settings.json`):

| Event | Matcher | Purpose |
|-------|---------|---------|
| `SessionStart` | (none) | Inject build-authorization reminder as `system-reminder` (no "may or may not be relevant" disclaimer) |
| `PreCompact` | (none) | Re-inject your hard rules so they survive compaction (template - customize) |
| `PreToolUse` | `Agent` | Pre-spawn checklist reminder (token estimate, tool-call caps, WebFetch caps) |
| `PreToolUse` | `mcp__.*__(list\|search)_` | Probe-before-pull reminder |
| `PreToolUse` | `Write\|Edit` | Sensitive-path warning (template - customize) |
| `PreToolUse` | `Bash` | Dangerous-git warning (ships ready) |
| `PostToolUse` | `Bash` | Deployment reminder after `git push` (template - customize) |
| `PostToolUse` | `Write\|Edit` | Docs-sync reminder (template - customize) |
| `Stop` | (none) | End-of-turn uncommitted-changes check (template - customize) |

---

## Why hard link, not symlink, on Windows

`New-Item -ItemType SymbolicLink` requires Administrator OR Windows Developer Mode enabled. Hard links (`mklink /H`) work for any file on the same volume without elevated privileges.

**Hard link caveat (CONFIRMED in practice):** if an editor or tool saves settings.json via the atomic-rename pattern (write tempfile, rename over original), the hard link breaks - `.claude/settings.json` becomes a new file no longer linked to `claude-config/settings.json`. **Claude Code's Edit tool uses atomic-rename and breaks the link on every edit.** The link has to be re-created with `mklink /H`.

**Mitigation (in priority order):**

1. **STRONGLY RECOMMENDED - Enable Windows Developer Mode** (Settings -> For developers -> Developer Mode ON). Re-run `bootstrap.ps1` and it upgrades the hard link to a symlink. Symlinks survive atomic-rename. This is the only fix that prevents the issue.
2. **Always edit the canonical file** (`claude-config/settings.json`), not `~/.claude/settings.json` - but this only helps if the editor preserves the inode on save (most do not, including Claude Code's Edit tool).
3. **Re-run `bootstrap.ps1`** after any settings edit if you're stuck on hard links. The script detects the broken state and re-creates the link.

The atomic-rename failure is silent - hooks just stop updating on other PCs. Check periodically with `diff` against the canonical file.

---

## Verify the link is still active

If hooks stop firing on a PC that previously had them, the link may have broken. Check:

```powershell
fsutil hardlink list "$env:USERPROFILE\.claude\settings.json"
# Should list BOTH paths if the hard link is intact.
# If only one path is listed, the link is broken - re-create via bootstrap.ps1 or mklink /H.
```

For a symbolic link, check via:

```powershell
Get-Item "$env:USERPROFILE\.claude\settings.json" | Select-Object LinkType, Target
# LinkType should be "SymbolicLink"; Target should point to claude-config/settings.json
```

---

## Editing hooks

**Always edit the canonical file:**
```powershell
code claude-config/settings.json
# or
notepad claude-config/settings.json
```

Then commit + push:
```powershell
git add claude-config/settings.json
git commit -m "hooks: <what changed>"
git push
```

Other PCs pick up the new hooks on next `git pull` (the link makes both paths show the new content - if Developer Mode is on with a symlink. With hard links, re-run bootstrap.ps1 after pull to re-link if Edit broke the original.)

---

## Excluded from this pattern

- `~/.claude/settings.local.json` - local-only machine overrides. NOT tracked, NOT linked.
- `~/.claude/.credentials.json` and similar - secrets. NOT tracked.
- `~/.claude/projects/`, `~/.claude/sessions/`, `~/.claude/plugins/` - machine state. NOT tracked.

Only `settings.json` (hooks/permissions/env config) is canonical-in-repo. Everything else stays local.
