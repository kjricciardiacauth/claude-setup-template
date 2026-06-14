# Guide: Supercharge Your Claude Code Setup

The front-door reading path for this template. Point Claude Code at this repo and your sessions get better out of
the box - this guide explains what's here, in the order worth learning it. Each section is a short orientation
plus links into the concrete files.

If you just want it running: [`README.md`](README.md) (quick start) -> [`SETUP.md`](SETUP.md) (full install).
This guide is the "why and what", organized as a curriculum.

---

## 1. Fundamentals - how context loads
Claude Code assembles context in tiers. Get this model first; everything else hangs off it.

- **Four-tier loading:** always-on rules -> project `CLAUDE.md` -> path-scoped rules -> on-demand skills/memory/docs.
- Read [`docs/architecture.md`](docs/architecture.md) for the rationale and [`docs/why-this-pattern.md`](docs/why-this-pattern.md) for the design decisions.
- The agent entrypoint is [`AGENTS.md`](AGENTS.md) (imported by `CLAUDE.md`). Memory lives in [`memory/`](memory/) - a lean always-on [`core-rules.md.template`](memory/core-rules.md.template) plus an [`MEMORY.md`](memory/MEMORY.md.template) index that points at on-demand topic files. Keep always-on context small; the research behind that is in [`memory/llm_context_best_practices.md`](memory/llm_context_best_practices.md).

## 2. Tools - the CLI that makes Claude fast
A small set of fast CLIs changes how much Claude can do per turn.

- Installed by `install-cli.{ps1,sh}`: Tier 1 (`rg`, `fd`, `bat`, `fzf`, `jq`, `xh`, `zoxide`) + Tier 2 (`lazygit`, `gron`, `uv`, `starship`, `gh-dash`).
- See [`docs/cli-quickstart.md`](docs/cli-quickstart.md) for what each replaces and [`memory/cli_toolset.md`](memory/cli_toolset.md) for the full reference.

## 3. Hooks - enforcement that survives a long session
Rules in prose decay; hooks don't. This template ships a hook stack in [`claude-config/hooks/`](claude-config/hooks/), wired in `claude-config/settings.{windows,mac}.json`.

- **Always-active (no setup):** the activity ledger (`session-log-*`), the verification gate (`stop-verify-gate`), the secrets-write scanner (`pre-write-secrets-scan`), and the GitHub identity guard (`pre-bash-github-identity`).
- **Opt-in `.template`s:** the board gate (`stop-board-gate`) plus the customizable templates (compaction rules, sensitive paths, deploy reminders, end-of-turn checks).
- Each hook ships in both `.ps1` (Windows) and `.sh` (Mac/Linux), fails open, and is ASCII-only. The "What to customize" table in [`README.md`](README.md) lists every `.template`.

## 4. Rules - scoped guidance
Reference rules in [`claude-config/rules/`](claude-config/rules/) load when relevant.

- [`git.md`](claude-config/rules/git.md) - commit/staging/sync conventions.
- [`github-rules.md`](claude-config/rules/github-rules.md) + [`github-projects.json.template`](claude-config/rules/github-projects.json.template) - opt-in board + identity discipline (enables `stop-board-gate`).
- [`workers.md`](claude-config/rules/workers.md) - Cloudflare Workers deploy conventions (loads only for worker files).

## 5. Best Practices - the habits that pay off
The operating principles this template encodes, each with the reasoning: [`docs/best-practices.md`](docs/best-practices.md). Plan-first, verify-before-done, probe-before-pull, debugging discipline, git hygiene, present-options, token-efficient delegation, PDF reading, security, memory hygiene.

## 6. Workflows - running substantive work
How to take a non-trivial change from idea to merge: [`docs/workflows.md`](docs/workflows.md). The brainstorm -> plan -> execute -> finish chain (mapped onto the open-source superpowers skills), plus the parallel-lane worktree pattern for splitting independent work.

---

## Where to start
- **New here:** sections 1 -> 2, then run the install from [`README.md`](README.md).
- **Want the enforcement:** section 3, then [`docs/best-practices.md`](docs/best-practices.md).
- **Running real projects through it:** [`docs/workflows.md`](docs/workflows.md).

Everything is MIT-licensed and project-agnostic. Take what helps, drop what doesn't.
