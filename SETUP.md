# Setup - Manual Step-by-Step

For the AI-driven version, see [`AGENTS.md`](AGENTS.md). Run Claude Code in auto mode and say "Bootstrap me from this repo as `<username>` / `<email>`" - it will execute that file.

For the manual version, follow these steps.

---

## Prerequisites

- Windows 10 or 11
- PowerShell 5.1+ (built in) or PowerShell 7+ (recommended)
- winget (Windows Package Manager - built into Windows 11; install "App Installer" from Microsoft Store on Windows 10)
- A GitHub account and a commit email

---

## 1. Install Git + GitHub CLI

```powershell
winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
```

## 2. Authenticate gh

```powershell
gh auth login
```

Choose GitHub.com -> HTTPS -> Authenticate via web browser. Sign in to the account you'll use.

## 3. Clone this repo

```powershell
git clone https://github.com/kjricciardiacauth/claude-setup-template.git
cd claude-setup-template
```

## 4. Run bootstrap

```powershell
.\bootstrap.ps1 -Username "your-github-username" -Email "you@example.com"
```

Expected output:

```
=== Claude Code dev environment bootstrap ===
Identity: your-github-username / you@example.com

[ok]      Git already installed
[ok]      GitHub CLI already installed
[install] Node.js...
[ok]      @anthropic-ai/claude-code already installed (claude on PATH)
[ok]      created memory junction ...
[ok]      created commands junction ...
[ok]      created skills junction ...
[ok]      created rules junction ...
[ok]      created hooks junction ...
[ok]      created settings.json hard link (enable Developer Mode for symlink - more robust)
[ok]      set repo identity: your-github-username / you@example.com

=== Tier 1 CLI foundation ===
[install] ripgrep (rg)...
[install] fd...
... etc

=== Verification ===
[PASS]    memory junction
[PASS]    commands junction
[PASS]    skills junction
[PASS]    rules junction
[PASS]    hooks junction
[PASS]    settings link
[PASS]    ~/.claude/CLAUDE.md
[PASS]    claude CLI installed
[PASS]    git identity set

=== Bootstrap complete - all checks passed ===
```

If any check fails, the script tells you which one. Most failures are recoverable by re-running the script.

## 5. (Recommended) Enable Windows Developer Mode

The bootstrap created a HARD LINK for `~/.claude/settings.json`. Hard links break when an editor saves via atomic-rename (Claude Code's Edit tool does this).

To use a SYMBOLIC LINK instead (survives atomic-rename):

1. Open Windows Settings
2. System -> For developers
3. Toggle "Developer Mode" ON
4. Close and re-run `.\bootstrap.ps1 -Username ... -Email ...` to upgrade the link

## 6. Customize the templates

Six files ship with `.template` suffix because they need your project context. See [README.md](README.md) for the full list and what each one is.

Quickest path:

```powershell
# Memory templates
Move-Item memory\MEMORY.md.template memory\MEMORY.md
Move-Item memory\core-rules.md.template memory\core-rules.md
# Then open each in your editor and fill in YOUR project info

# Hook templates - rename only the ones you want active
Move-Item claude-config\hooks\pre-compact-rules.ps1.template claude-config\hooks\pre-compact-rules.ps1
Move-Item claude-config\hooks\stop-end-of-turn.ps1.template claude-config\hooks\stop-end-of-turn.ps1
# ... etc, customize each
```

You can leave any `.template` file as-is - that hook simply won't fire until you rename it.

## 7. Restart Claude Code

Open a new terminal (so PATH refreshes from the npm and winget installs), then:

```powershell
claude
```

The new session loads:

- Memory files from `memory/` (via the junction to `~/.claude/projects/<encoded>/memory/`)
- Skills from `skills/` (via junction)
- Rules from `claude-config/rules/`
- Hooks from `claude-config/settings.json` (via link to `~/.claude/settings.json`)
- The `core-rules.md` import at the top of `~/.claude/CLAUDE.md`

## 8. Commit your customizations

After you've filled in the `.template` files:

```powershell
git add memory/MEMORY.md memory/core-rules.md claude-config/hooks/*.ps1
git commit -m "customize hooks and memory for my project"
git push
```

Other PCs you set up later will `git clone` then `bootstrap.ps1` - your customizations come with the clone.

---

## Troubleshooting

### "Bootstrap.ps1 cannot be loaded because running scripts is disabled"

Run with the bypass flag:
```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Username "..." -Email "..."
```
The script itself sets `RemoteSigned` for your user scope after running once.

### "settings.json hard link broken"

Check:
```powershell
diff "$env:USERPROFILE\.claude\settings.json" "claude-config\settings.json"
```

If they differ, the link broke (probably from an Edit-tool save). Re-link:
```powershell
.\bootstrap.ps1 -Username "..." -Email "..."
```
The script detects the broken link and re-creates it.

Long-term fix: enable Developer Mode (step 5) so the link is a symlink that survives atomic-rename.

### "Claude doesn't see my new memory file"

Memory files load at session start. After adding or editing a file in `memory/`, close and reopen `claude`.

If even a fresh session doesn't see it:
- Check the junction is intact: `Get-Item "$env:USERPROFILE\.claude\projects\<encoded>\memory"` should show `ReparsePoint` in Attributes
- Verify `MEMORY.md` exists in the source folder
- Re-run `bootstrap.ps1` to recreate the junction if needed

### Verification step fails

Re-read the `[FAIL]` line. Common ones:

- `[FAIL] claude CLI installed` - npm install hasn't propagated to PATH. Open a NEW terminal.
- `[FAIL] settings link` - source file missing or path collision. Check `claude-config/settings.json` exists.
- `[FAIL] git identity set` - the script's `git config` command failed. Run manually: `git config user.email "you@example.com"`.

---

## What gets installed where

| Location | Purpose | Source |
|----------|---------|--------|
| `~/.claude/CLAUDE.md` | User-scope import of core rules | Created by bootstrap (one line: `@<repo>/memory/core-rules.md`) |
| `~/.claude/projects/<encoded>/memory/` | Memory directory Claude auto-loads | Junction -> `<repo>/memory/` |
| `~/.claude/commands/` | Slash command definitions | Junction -> `<repo>/commands/` |
| `~/.claude/skills/` | Skills available to Claude | Junction -> `<repo>/skills/` |
| `~/.claude/rules/` | Path-scoped behavior rules | Junction -> `<repo>/claude-config/rules/` |
| `~/.claude/hooks/` | Helper scripts called by hooks | Junction -> `<repo>/claude-config/hooks/` |
| `~/.claude/settings.json` | Hooks + permissions config | Link (symlink or hard link) -> `<repo>/claude-config/settings.json` |
| `C:\Program Files\Git\...` | Git binary | winget install |
| `C:\Program Files\GitHub CLI\...` | gh binary | winget install |
| `C:\Program Files\nodejs\...` | Node.js + npm | winget install |
| `%APPDATA%\npm\claude.cmd` | Claude Code CLI | `npm install -g @anthropic-ai/claude-code` |
| Various (winget) | Tier 1 CLI tools | `install-cli.ps1 -Tier 1` |
| `%USERPROFILE%\scoop\` | scoop + Tier 2 scoop tools | `install-cli.ps1 -Tier 2` |
