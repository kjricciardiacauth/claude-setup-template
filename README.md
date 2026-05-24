# claude-setup-template

A starter template for setting up a Claude Code dev environment that actually works.

Opinionated. Battle-tested across daily use, dozens of sessions, real bugs caught.

## What you get

- **Bootstrap script** that installs Claude Code, sets up `~/.claude/` junctions to this repo, and configures git identity - all idempotent, all driven by command-line flags.
- **Hook stack** (8 hooks, 1 universal + 5 templates) that enforce build-authorization, warn before dangerous git commands, remind about deploys, check for uncommitted work at end of every turn, and re-inject your rules after context compaction.
- **Memory architecture** with proven patterns: domain-grouped MEMORY.md index, on-demand topic files, skill-vs-memory routing rationale.
- **CLI installer** for the 12 tools that make working in Claude Code dramatically faster (Tier 1: rg, fd, bat, fzf, jq, xh, zoxide. Tier 2: lazygit, gron, uv, starship, gh-dash).
- **Research brief** distilling Anthropic docs + community findings on context architecture, CLAUDE.md size limits, anti-patterns - the WHY behind every pattern in this template.

## Autopilot install (Claude Code in auto mode)

Designed to be driven by Claude Code itself. On a fresh PC:

1. Install Claude Code via your preferred channel.
2. Clone this repo: `git clone https://github.com/kjricciardiacauth/claude-setup-template.git`
3. `cd claude-setup-template && claude --permission-mode auto`
4. Type to Claude:

   > **Bootstrap me from this repo as <your-github-username> / <your-email>**

Claude reads `AGENTS.md` and runs the install end-to-end. It stops only at the explicit auth step (`gh auth login` requires a human in the browser). Total time: ~5 minutes on a clean machine, ~30 seconds if everything is already installed.

## Manual install

If you prefer to drive it yourself:

```powershell
git clone https://github.com/kjricciardiacauth/claude-setup-template.git
cd claude-setup-template
.\bootstrap.ps1 -Username "<your-username>" -Email "<your-email>"
gh auth login
# customize the .template files - see "What to customize" below
claude
```

See [`SETUP.md`](SETUP.md) for the full step-by-step.

## What to customize after install

Several files ship with `.template` suffix because they need YOUR project context:

| File | What to fill in |
|------|----------------|
| `memory/MEMORY.md.template` -> `MEMORY.md` | Your domain section headers + topic file pointers |
| `memory/core-rules.md.template` -> `core-rules.md` | Your hard rules, conventions, security policies |
| `claude-config/hooks/pre-compact-rules.ps1.template` -> `.ps1` | Your hard rules to re-inject after compaction |
| `claude-config/hooks/pre-write-sensitive-path.ps1.template` -> `.ps1` | Your sensitive paths (legal/, .env, etc.) |
| `claude-config/hooks/post-bash-git-push.ps1.template` -> `.ps1` | Your post-deploy reminder text |
| `claude-config/hooks/post-edit-mcp-docs.ps1.template` -> `.ps1` | Your doc-sync trigger paths |
| `claude-config/hooks/stop-end-of-turn.ps1.template` -> `.ps1` | Your repo paths to check for uncommitted work |

The `.template` extension keeps these hooks inactive until you customize them. The settings.json wiring references them all - they no-op silently when the script doesn't exist yet.

## Why this template exists

Most Claude Code "setup guides" are docs. This is a working repo you can clone and `git pull` to keep in sync across machines. It encodes patterns proven over real daily use:

- **Hooks beat CLAUDE.md for compliance.** Anthropic wraps CLAUDE.md with "may or may not be relevant" framing - hooks inject as clean system-reminders that Claude treats as authoritative.
- **Memory files beat skills for reliability.** Skill auto-activation depends on description matching that's hit-or-miss. Auto-memory recall reliably fires - so trim memory files small and rely on them.
- **PowerShell on Windows is cp1252.** Em-dashes in scripts break parsing silently. The hook templates use ASCII-only punctuation.
- **The Edit tool uses atomic-rename.** That breaks hard links to `settings.json`. Enable Developer Mode for symlinks - documented in `bootstrap.ps1` output.
- **`-ErrorAction SilentlyContinue` doesn't catch terminating errors.** `Set-ExecutionPolicy` overridden by Group Policy throws a terminating error that bypasses it. Wrap in try/catch.

All of these are bugs I hit personally during the deploy that produced this template. They're now baked in as defaults so you don't hit them.

## Architecture overview

Four-tier context loading:

| Tier | What | When loaded |
|------|------|-------------|
| Always-on | `~/.claude/CLAUDE.md` -> imports `core-rules.md` | Every session |
| Project-scoped | `<repo>/CLAUDE.md` | When that repo is open |
| Path-scoped | `claude-config/rules/*.md` with `paths:` frontmatter | When matching files are active |
| On-demand | Skills, memory topic files, docs/tool-references/ | When invoked or referenced |

See [`docs/architecture.md`](docs/architecture.md) for the rationale and [`memory/llm_context_best_practices.md`](memory/llm_context_best_practices.md) for the research it's based on.

## Platform support

**Windows-first.** Bootstrap script is PowerShell. CLI installer uses winget + scoop. The hook scripts are PowerShell.

Mac / Linux would need translation - the architectural patterns (junctions, hooks, memory structure) transfer cleanly but the implementation is Windows-specific.

## License

MIT. Take it, fork it, ship it. Credit appreciated but not required.

## Related reading

- [Anthropic - Claude Code skills](https://code.claude.com/docs/en/skills)
- [Anthropic - Memory and CLAUDE.md](https://code.claude.com/docs/en/memory)
- [Anthropic - Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)
