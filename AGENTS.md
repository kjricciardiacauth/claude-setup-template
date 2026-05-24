# Autopilot Bootstrap Guide

**For Claude Code running in auto mode.** When the user says any of:

- "Bootstrap me from this repo as `<username>` / `<email>`"
- "Set me up using this repo with username `<X>` and email `<Y>`"
- "Run the bootstrap"

...execute the steps below in order. Stop ONLY at the explicit STOP points.

## Required inputs

The user must provide a GitHub username AND a commit email when they invoke you. If either is missing, ask once:

> "I need two things to run bootstrap: your GitHub username and your commit email. Please provide both."

Wait for both. Do not proceed otherwise.

---

## Step 1: Verify platform

```powershell
Get-Command winget
```

- **PASS:** winget is found. Continue to Step 2.
- **FAIL:** STOP. Tell the user:
  > "I need `winget` (Windows Package Manager). Open Microsoft Store, search 'App Installer', install it, then say 'continue'."
  
  Wait for confirmation. Re-run the check.

## Step 2: Verify Claude Code session has the right permissions

The user should have started this session with `claude --permission-mode auto`. If they didn't, the bootstrap will hit per-command permission prompts that the auto-mode classifier would otherwise pass through.

Test by running a benign command:
```powershell
Get-Location
```

If you got a permission prompt, STOP and tell the user:
> "This session isn't in auto mode. Exit and re-launch with `claude --permission-mode auto`, then re-issue the bootstrap command."

## Step 3: Install Git, GitHub CLI, Node.js

These are well-known packages - the auto-mode classifier passes them through.

```powershell
winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
winget install --id OpenJS.NodeJS --silent --accept-source-agreements --accept-package-agreements
```

Each command exits 0 on success OR if already installed. If any returns non-zero, surface the error and STOP.

## Step 4: Refresh PATH

```powershell
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
```

## Step 5: STOP - GitHub authentication

```powershell
gh auth status
```

- **If output contains "Logged in to github.com":** authentication is done. Continue to Step 6.
- **Otherwise:** STOP. Tell the user:

  > "Run this in a separate terminal: `gh auth login`
  >
  > Sign in to github.com with HTTPS, authenticate via web browser, complete the device-code flow.
  >
  > When you see 'Logged in as <username>', come back and say 'done'."

  Wait for the user to confirm. Re-run `gh auth status` and verify before continuing.

## Step 6: Run bootstrap.ps1

The user already provided `<username>` and `<email>`. Run:

```powershell
.\bootstrap.ps1 -Username "<username>" -Email "<email>"
```

Expected last line of output:
```
=== Bootstrap complete - all checks passed ===
```

If you see "with N failed check(s)" instead:
- Read the `[FAIL]` lines from the verification block
- Surface each failure to the user with a one-line diagnosis
- STOP - do not proceed to Step 7

If the script succeeds, continue.

## Step 7: Install CLI tools

`bootstrap.ps1` invokes `install-cli.ps1 -Tier All` automatically unless `-SkipCli` was passed. If it was skipped, run it now:

```powershell
.\install-cli.ps1 -Tier All
```

## Step 8: Help the user customize their hooks and memory

Tell the user:

> "Bootstrap is complete. Six files have a `.template` suffix because they need YOUR project context:
>
> - `memory/MEMORY.md.template` -> rename to `MEMORY.md` and fill in your domain section pointers
> - `memory/core-rules.md.template` -> rename to `core-rules.md` and fill in your hard rules
> - `claude-config/hooks/*.template` (5 files) -> rename to `.ps1` and customize each
>
> Tell me which to start with (or 'all of them' and I'll walk through each), or say 'I'll do it myself' if you want to handle it later."

Wait for the user's choice. If they want help, walk through each file: read the `.template`, ask the user the specific questions inside, write the customized `.ps1` (or `.md`), confirm.

## Step 9: STOP - restart Claude

Tell the user:

> "Setup complete. You need to restart Claude Code for the new hooks, memory, and skills to load.
>
> 1. Type `/exit` to close this session.
> 2. Open a new terminal (so PATH refreshes from the install).
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
3. Offer to retry from that step (don't restart from Step 1).

Common failures and fixes:

| Failure | Likely cause | Fix |
|---------|--------------|-----|
| `Set-ExecutionPolicy: Security error` | Group Policy override | Ignore - script handles it via try/catch |
| `winget : command not found` | winget not installed | Step 1's STOP path |
| `gh: not found` in Step 5 | gh install hasn't propagated to PATH yet | Re-run Step 4 (PATH refresh) |
| `npm error code ENOENT` `%APPDATA%\npm` | Empty npm global dir | Script creates this automatically; if it still fails, run `New-Item -ItemType Directory -Force -Path "$env:APPDATA\npm"` |
| `[FAIL] settings link` | Path collision with existing file | bootstrap backs up and links - if it still fails, the source file is probably missing |
| Verification shows `[FAIL] claude CLI installed` | Fresh install hasn't propagated to PATH | User needs to open a new terminal |

---

## What this guide is NOT

- Not a full configuration system. It sets up the FRAMEWORK. The user customizes the `.template` files themselves (or with your help in Step 8).
- Not a multi-repo bootstrap. This template assumes one repo. The user adapts it for their actual projects.
- Not a deployment automation. There are no production deploys in this script. It's a developer environment setup.

If the user asks you to do things outside this guide ("also clone repo X, also set up Y MCP server"), do them as separate follow-up actions after Step 9 - don't bundle them into the bootstrap.
