# Hooks - How to Author and Activate

Hooks are the *enforced* layer of Claude Code behavior. Unlike CLAUDE.md instructions (which Claude is told are "may or may not be relevant"), hook output is injected as clean `system-reminder` messages that Claude treats as authoritative.

## What ships in this directory

Every hook ships in **both** `.ps1` (Windows / PowerShell) and `.sh` (Mac / Linux / bash) variants. Customize the one matching your platform.

| File | Status | What it does |
|------|--------|-------------|
| `pre-bash-git-dangerous.{ps1,sh}` | **Ready to use** | Warns on `git add -A`, force push, `reset --hard`, `--no-verify`, etc. Universal - no customization needed. |
| `pre-compact-rules.{ps1,sh}.template` | **Customize** | Re-injects YOUR hard rules every time context is compacted. Survives the summarization step that loses CLAUDE.md content. |
| `pre-write-sensitive-path.{ps1,sh}.template` | **Customize** | Warns before edits to YOUR sensitive paths (legal/, payroll/, .env, etc.). |
| `post-bash-git-push.{ps1,sh}.template` | **Customize** | Reminder after `git push` - customize for YOUR deploy log / CI link / verification step. |
| `post-edit-mcp-docs.{ps1,sh}.template` | **Customize** | "FILE CHANGED, sync docs?" - fires only on paths YOU mark as docs-relevant. |
| `stop-end-of-turn.{ps1,sh}.template` | **Customize** | Checks YOUR repo list for uncommitted work at end of every turn. |

The hook wiring lives in two settings files (one per platform):

- Windows: `claude-config/settings.windows.json` - hooks call `$env:USERPROFILE\.claude\hooks\<script>.ps1`
- Mac/Linux: `claude-config/settings.mac.json` - hooks call `$HOME/.claude/hooks/<script>.sh`

`bootstrap.ps1` symlinks (or hard-links) the Windows variant into `~/.claude/settings.json`; `bootstrap.sh` symlinks the Mac variant. Junctions from `~/.claude/hooks/` -> `claude-config/hooks/` mean BOTH platform script files live in the same directory; only the ones that match the platform's settings file actually get invoked.

## Activating a template

Each template file has comments showing where to customize. To activate:

1. Open the `.template` file in `claude-config/hooks/`
2. Edit the marked sections to fit your project
3. Rename: drop the `.template` suffix
   - Windows: `<name>.ps1.template` -> `<name>.ps1`
   - Mac/Linux: `<name>.sh.template` -> `<name>.sh` AND run `chmod +x <name>.sh`
4. Commit + push (so other machines pick it up)

The template extension keeps the hook from firing until you customize it. Both settings files wire all hooks unconditionally - they no-op silently (via `2>/dev/null || true` on Mac, missing-file-detection on Windows) if the script doesn't exist yet.

## Why helper scripts instead of inline `if:` filters

The `if` field in a hook entry (e.g. `"if": "Bash(git push*)"`) does NOT reliably gate execution. In testing, hooks fired on every matching tool call regardless of the `if` pattern. Helper scripts that read stdin and inspect `tool_input.command` work reliably.

Pattern:
```powershell
$inputJson = [Console]::In.ReadToEnd()
if (-not $inputJson) { exit 0 }
$data = $inputJson | ConvertFrom-Json
$command = $data.tool_input.command  # or $data.tool_input.file_path for Write|Edit
if ($command -notmatch '<your pattern>') { exit 0 }
# emit hook JSON
```

## Lessons learned the hard way

1. **PowerShell scripts must be ASCII-only.** Windows defaults to cp1252 codepage; em-dashes (—) and smart quotes in scripts get mojibake'd and break parsing. Use `-` instead of `—`.

2. **`$varName:` is a drive prefix.** PowerShell parses `:` in interpolated strings as a drive namespace separator. Use `"${var}:"` not `"$var:"`.

3. **`-ErrorAction SilentlyContinue` doesn't suppress terminating errors.** Cmdlets like `Set-ExecutionPolicy` that throw terminating errors bypass it. Wrap in `try { Cmd -ErrorAction Stop } catch {}` to truly swallow.

4. **Edit tool validates BEFORE PreToolUse hook fires.** "File must exist" / "must Read first" preconditions short-circuit before the hook sees the call. To test a Write|Edit sensitive-path hook, use **Write** to a non-existent path in a sensitive directory (Write doesn't have the pre-existence check).

5. **Hard links break on atomic-rename saves.** If your editor (or Claude Code's Edit tool) saves files by writing a tempfile and renaming over the original, the hard link breaks silently. Enable Windows Developer Mode and use symlinks instead - `bootstrap.ps1` prefers symlink when available.

See `memory/hooks_sync_pattern.md` for the full cross-PC sync model.
