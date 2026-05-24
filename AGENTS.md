# Autopilot Bootstrap Guide

**For Claude Code running in auto mode.** When the user says any of:

- "Bootstrap me from this repo as `<username>` / `<email>`"
- "Set me up using this repo with username `<X>` and email `<Y>`"
- "Run the bootstrap"

...follow Step 0 to detect the platform, then execute the matching platform path. Stop ONLY at the explicit STOP points.

## Required inputs

The user must provide a GitHub username AND a commit email when they invoke you. If either is missing, ask once:

> "I need two things to run bootstrap: your GitHub username and your commit email. Please provide both."

Wait for both. Do not proceed otherwise.

---

## Step 0: Detect platform

Run this PowerShell snippet (works on Windows; harmless on Mac/Linux if pwsh is installed):

```powershell
if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'WINDOWS' } else { 'OTHER' }
```

Or run bash (works on Mac/Linux):

```bash
uname -s
```

- Result `WINDOWS` or PowerShell-on-Windows -> follow the **WINDOWS PATH** below.
- Result `Darwin` -> follow the **MAC PATH** below.
- Result `Linux` -> follow the **MAC PATH** below (works for most Linux distros; brew/apt detection handled in bootstrap.sh).

If you can't determine the platform, ASK: "Are you on Windows, Mac, or Linux?"

---

# WINDOWS PATH

## W1: Verify winget

```powershell
Get-Command winget
```

- **PASS:** continue to W2.
- **FAIL:** STOP. Tell the user: *"I need `winget`. Open Microsoft Store, search 'App Installer', install it, then say 'continue'."* Wait for confirmation. Re-run the check.

## W2: Verify auto mode

This session should have been started with `claude --permission-mode auto`. Test by running a benign command:

```powershell
Get-Location
```

If you got a permission prompt, STOP and tell the user:
> "This session isn't in auto mode. Exit and re-launch with `claude --permission-mode auto`, then re-issue the bootstrap command."

## W3: Install Git, GitHub CLI, Node.js

```powershell
winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
winget install --id OpenJS.NodeJS --silent --accept-source-agreements --accept-package-agreements
```

Each command exits 0 on success OR if already installed. If any returns non-zero, surface the error and STOP.

## W4: Refresh PATH

```powershell
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
```

## W5: STOP - GitHub authentication

```powershell
gh auth status
```

- **If output contains "Logged in to github.com":** continue to W6.
- **Otherwise:** STOP. Tell the user:

  > "Run this in a separate terminal: `gh auth login`
  >
  > Sign in to github.com with HTTPS, authenticate via web browser, complete the device-code flow. When you see 'Logged in as <username>', come back and say 'done'."

  Wait for confirmation. Re-run `gh auth status` and verify before continuing.

## W6: Run bootstrap.ps1

```powershell
.\bootstrap.ps1 -Username "<username>" -Email "<email>"
```

Expected last line:
```
=== Bootstrap complete - all checks passed ===
```

If "with N failed check(s)" instead - surface the `[FAIL]` lines, STOP, do not proceed.

## W7: (CLI installer ran automatically in W6 unless -SkipCli was used)

If it was skipped, run:
```powershell
.\install-cli.ps1 -Tier All
```

## W8: Walk through customizations

Jump to **CUSTOMIZE SECTION** below.

---

# MAC PATH

## M1: Verify Homebrew (Mac only) / package manager (Linux)

```bash
# Mac:
command -v brew

# Linux:
command -v apt-get || command -v dnf
```

- **brew found:** continue to M2.
- **brew missing on Mac:** the bootstrap script will install it. Continue to M2.
- **apt/dnf found on Linux:** continue to M2 (bootstrap.sh handles both).

## M2: Verify auto mode

Test:
```bash
pwd
```

If you got a permission prompt, STOP and tell the user:
> "This session isn't in auto mode. Exit and re-launch with `claude --permission-mode auto`, then re-issue the bootstrap command."

## M3: STOP - GitHub authentication

```bash
gh auth status
```

If gh isn't installed yet (Linux case where bootstrap will install it), continue to M4 and re-check after.

If gh is installed but not authed, STOP:

> "Run this in a separate terminal: `gh auth login`
>
> Sign in to github.com with HTTPS, authenticate via web browser. When you see 'Logged in as <username>', come back and say 'done'."

Wait for confirmation.

## M4: Run bootstrap.sh

```bash
chmod +x bootstrap.sh
./bootstrap.sh --username "<username>" --email "<email>"
```

On a fresh Mac, this will install Homebrew (may take 1-2 minutes and prompt for sudo password once - that's expected, the script does NOT pass through to gh auth or interactive flows beyond this single brew install).

Expected last line:
```
=== Bootstrap complete - all checks passed ===
```

If "with N failed check(s)" - surface the `[FAIL]` lines, STOP, do not proceed.

## M5: (CLI installer ran automatically in M4 unless --skip-cli was used)

If it was skipped:
```bash
./install-cli.sh --tier all
```

## M6: Re-check gh auth if it was missing in M3

```bash
gh auth status
```

If still not authed, do the STOP-and-ask routine from M3 now.

## M7: Walk through customizations

Jump to **CUSTOMIZE SECTION** below.

---

# CUSTOMIZE SECTION (both platforms)

Tell the user:

> "Bootstrap is complete. Several files have `.template` suffix because they need YOUR project context:
>
> - `memory/MEMORY.md.template` -> rename to `MEMORY.md` and fill in your domain section pointers
> - `memory/core-rules.md.template` -> rename to `core-rules.md` and fill in your hard rules
> - `claude-config/hooks/*.template` (5 files) -> rename to `.ps1` (Windows) or `.sh` (Mac/Linux) and customize each
>
> Tell me which to start with (or 'all of them' and I'll walk through each), or say 'I'll do it myself' if you want to handle it later."

Wait for the user's choice. If they want help, walk through each file: read the `.template`, ask the user the specific questions inside, write the customized file, confirm.

**File extension by platform:**
- Windows: `<name>.ps1.template` -> rename to `<name>.ps1`
- Mac/Linux: `<name>.sh.template` -> rename to `<name>.sh` AND `chmod +x <name>.sh`

The repo ships BOTH platform variants. Customizing the wrong one is harmless (it just won't fire), but customize the one matching the user's platform.

# FINAL STEP (both platforms)

Tell the user:

> "Setup complete. You need to restart Claude Code for the new hooks, memory, and skills to load.
>
> 1. Type `/exit` to close this session.
> 2. Open a new terminal (so PATH refreshes from any tool installs).
> 3. Run `claude` to start fresh.
>
> The next session will have:
> - Your build-authorization SessionStart hook firing
> - Your customized hooks active
> - Memory files auto-recalling
> - CLI tools (rg, fd, jq, etc.) on PATH"

---

## Failure recovery

If any step fails:

1. Surface the exact error to the user (don't paraphrase - paste the stderr).
2. Suggest the most likely fix from the script's own diagnostics.
3. Offer to retry from that step (don't restart from Step 0).

### Windows common failures

| Failure | Likely cause | Fix |
|---------|--------------|-----|
| `Set-ExecutionPolicy: Security error` | Group Policy override | Ignore - script handles it via try/catch |
| `winget : command not found` | winget not installed | Step W1's STOP path |
| `gh: not found` in Step W5 | gh install hasn't propagated to PATH | Re-run Step W4 (PATH refresh) |
| `npm error code ENOENT` `%APPDATA%\npm` | Empty npm global dir | Script creates this automatically; if it still fails, run `New-Item -ItemType Directory -Force -Path "$env:APPDATA\npm"` |
| `[FAIL] settings link` | Path collision with existing file | Bootstrap backs up and links - if it still fails, the source file is probably missing |

### Mac/Linux common failures

| Failure | Likely cause | Fix |
|---------|--------------|-----|
| `Homebrew install` prompts for sudo | Normal Homebrew first-install behavior | User must enter password once - STOP and tell them this is expected |
| `gh: command not found` after install | Shell PATH cache not refreshed | Open a new terminal or run `hash -r` |
| `Permission denied` on `./bootstrap.sh` | Script not executable | `chmod +x bootstrap.sh` then retry |
| `[FAIL] hooks symlink` | An existing directory is there | Bootstrap backs up - if it still fails, manually remove `~/.claude/hooks` and re-run |
| `npm error: EACCES` | npm trying to write to system dir | User likely installed Node via system package manager; reinstall via brew or fix npm prefix: `npm config set prefix ~/.npm-global` |

---

## What this guide is NOT

- Not a full configuration system. It sets up the FRAMEWORK. The user customizes the templates (or you help in CUSTOMIZE SECTION).
- Not a multi-repo bootstrap. Template assumes one repo.
- Not a deployment automation. No production deploys.

If the user asks you to do things outside this guide ("also clone repo X"), do them as separate follow-up actions after the final restart step - don't bundle them into the bootstrap.
