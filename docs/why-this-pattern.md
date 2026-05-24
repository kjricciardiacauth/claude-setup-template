# Why This Pattern

This template encodes specific choices that have been validated through real use. This doc explains why each choice was made, so you can re-decide them for your own setup.

## Why hooks over CLAUDE.md rules

**Tested failure mode:** A rule in CLAUDE.md ("never push to main without authorization") fired correctly in some sessions but was ignored in others. The pattern: long sessions where context filled and got compacted lost the rule entirely.

**Root cause:** Claude Code wraps CLAUDE.md content with framing like "this may or may not be relevant to the current task." During compaction, the model summarizes context away - including those rules.

**Fix:** Move enforceable rules to hooks. Hooks inject as `system-reminder` messages without the "may not be relevant" disclaimer. They're treated as authoritative. And a `PreCompact` hook re-injects them right before compaction so they survive.

**Reference:** "Your CLAUDE.md instructions are being ignored - here's why" (dev.to article, surfaced in the research brief).

## Why memory-first over skill-first

**Tested observation:** Created 9 skills with prescriptive descriptions ("Use when the user asks about HCP, jobs, list_jobs, employee IDs..."). In a fresh test session, only the most keyword-specific skill (Trello, which named all 6 boards explicitly) auto-triggered. The others lost to Claude Code's auto-memory recall mechanism, which pulled the full memory topic file instead.

**Conclusion:** Auto-memory recall is more aggressive than description-matched skill activation. If both paths exist for the same topic, the memory file wins.

**Implication for cost:** A skill body is ~80-100 lines (~5 KB). The full memory topic file is often 200-500+ lines (~15-40 KB). If you architect for skill-first but auto-memory wins, you pay the higher cost.

**Pragmatic fix:** Trim memory topic files small (target <200 lines). Move deep reference (full pipeline IDs, response shape examples) to `docs/tool-references/` which is OUTSIDE the memory directory and so NOT auto-recalled. Keep skills as opt-in `/skill-name` shortcuts (set `disable-model-invocation: true` to remove them from description budget).

This is the architecture this template defaults to.

## Why ASCII-only PowerShell scripts

**Tested failure mode:** Wrote hook scripts containing em-dashes (`—`) in user-facing strings and comments. Scripts parsed fine in VS Code preview. When PowerShell ran them in bootstrap context, they failed with cryptic parser errors:

```
Unexpected token 'risks' in expression or statement.
The string is missing the terminator: ".
```

The em-dash bytes (UTF-8 multi-byte sequence) were being interpreted as separate cp1252 characters, breaking the token stream.

**Root cause:** PowerShell on Windows defaults to cp1252 codepage. Files saved as UTF-8 with multi-byte characters get mojibake'd on load.

**Fix:** All `.ps1` files in this template use ASCII-only punctuation. Use `-` instead of em-dash. Use straight quotes (`"`, `'`) instead of curly.

## Why try/catch around `Set-ExecutionPolicy`

**Tested failure mode:** `bootstrap.ps1` had:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
```

On a machine where Group Policy or `--permission-mode Bypass` already set a higher scope, this command throws a TERMINATING error that `-ErrorAction SilentlyContinue` does not catch. Script aborts immediately.

**Fix:**
```powershell
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
} catch {
    # higher scope already permits scripts, no action needed
}
```

`-ErrorAction Stop` makes the error terminating, and `catch` actually catches it.

## Why prefer Get-Command over `npm list -g`

**Tested failure mode:** Bootstrap had:
```powershell
$found = npm list -g --depth=0 2>$null | Select-String -SimpleMatch $Pkg
```

On a clean Windows install where `%APPDATA%\npm` doesn't exist yet (common when Node.js is installed system-wide), `npm list -g` throws ENOENT and exits non-zero. The 2>$null suppresses stderr but PowerShell still treats the non-zero exit as failure under $ErrorActionPreference = "Stop".

**Fix:** Check if the executable is on PATH first:
```powershell
if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
    Write-Host "[ok] already installed"
    return
}
```

Only fall through to `npm install -g` if the binary isn't found. This bypasses `npm list -g` entirely.

## Why bootstrap takes -Username and -Email as flags

Two reasons:

1. **Auto-mode compatibility.** Claude Code in auto mode shouldn't be hit with interactive prompts. If bootstrap prompted "Enter your username:", the auto-mode classifier would either pass the prompt to the user (breaking the unattended flow) or fail. Flags up front mean Claude can invoke bootstrap with values it already has.

2. **Idempotence.** Re-running bootstrap with the same flags is a no-op. Re-running with different flags (changed email) updates the repo identity. No prompts means no ambiguity about what the second run did.

## Why settings.json is linked, not copied

If `~/.claude/settings.json` is a COPY of `claude-config/settings.json`:
- Edit in `~/.claude/settings.json` -> change is lost on next `git pull` if you pulled changes to `claude-config/settings.json` and copied over
- Edit in `claude-config/settings.json` -> change doesn't take effect until you re-copy
- Two PCs can drift silently

If they're LINKED (hard link or symlink):
- Edit either path -> both reflect the change
- `git pull` updates `claude-config/settings.json` -> `~/.claude/settings.json` automatically shows the new content
- No drift

Hard link works without Developer Mode but breaks on atomic-rename saves (the Edit tool does atomic-rename). Symlink survives atomic-rename but requires Developer Mode on Windows. Bootstrap prefers symlink and falls back to hard link.

## Why memory/ is the LLM's auto-memory directory

Claude Code automatically loads memory files from `~/.claude/projects/<encoded-cwd>/memory/`. The `<encoded-cwd>` is your current working directory with `:` and `\` replaced by `-` (e.g. `C:\Users\Admin` -> `C--Users-Admin`).

Bootstrap creates a junction from this path -> `<repo>/memory/`. Effect: every memory file you commit to the repo is auto-loaded the next time Claude starts in `C:\Users\Admin`.

If you want memory files for a DIFFERENT working directory, junction additional paths or set `autoMemoryDirectory` in settings.json.

## Why mirror remotes aren't in this template

The original setup (private) used a dual-push pattern: every push to the business GitHub account also pushed to a personal account as backup. Useful for organizational separation and disaster recovery.

For a public template, this pattern adds complexity without value for most users. Most people don't have two GitHub accounts. If you do, the pattern is documented in `memory/llm_context_best_practices.md` under "multi-repo".

## Why CLI Tier 2 is included by default

The Tier 1 tools (rg, fd, bat, fzf, jq, xh, zoxide) are foundational - they replace slow PowerShell-native commands with fast native binaries. Skipping them halves the value of having Claude on Windows.

Tier 2 (lazygit, gron, uv, starship, gh-dash) are situational but cheap to install. The marginal install cost is ~30 seconds. The marginal value when you need them is high (interactive rebases via lazygit, deeply nested JSON via gron, etc.).

Total install time for both tiers on a clean machine: ~2 minutes. Worth it.

## Lessons NOT encoded here

A few patterns from the original setup that aren't in this template:

- **MCP worker bootstrap.** The original had 10 MCP workers with specific Cloudflare configs. Too project-specific to template. Documented in research brief at high level.
- **Mirror remote setup.** See above.
- **Per-domain skill content** (HCP, GHL, QBO, etc.). All business-specific. The example skill shows the pattern without leaking content.
- **Deployment log automation.** Project-specific. The `post-bash-git-push.ps1.template` hook is the framework - you fill in the content.

If you find yourself wanting these patterns, fork the template and adapt. The architectural moves (junctions, links, hook templates, memory layering) all transfer cleanly.
