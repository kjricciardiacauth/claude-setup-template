# Architecture - The Layered Context Model

Claude Code loads context from multiple sources. Understanding which source feeds which scenario is the difference between a setup that works and one that quietly bloats every session.

## Four loading tiers

| Tier | Location | When loaded | Target size |
|------|----------|-------------|-------------|
| **Always-on** | `~/.claude/CLAUDE.md` (imports `core-rules.md`) | Every session, before any user prompt | <=80 lines |
| **Project-scoped** | `<repo>/CLAUDE.md` | When that specific repo is the working directory | <=120 lines |
| **Path-scoped** | `claude-config/rules/*.md` with `paths:` frontmatter | Only when files matching the glob are active | Any |
| **On-demand** | Skills (`skills/`), memory topic files (`memory/`), tool references (`docs/`) | When invoked or referenced | Any |

## The cost of each tier

| Tier | Per-session cost | Per-query cost |
|------|------------------|----------------|
| Always-on | High (every session pays it) | None additional |
| Project-scoped | Medium (only for that repo) | None additional |
| Path-scoped | Low (only when matching files touched) | None additional |
| On-demand | None (description listing only) | High when loaded |

So the rule of thumb: **put rare content in on-demand tiers, common content in always-on, with always-on as tight as possible.**

## What goes where

| Content type | Tier | Why |
|--------------|------|-----|
| Hard execution rules ("don't push until 'build'") | Always-on + Hook | Must be enforced every turn |
| Project conventions (naming, commit format) | Project-scoped CLAUDE.md | Only relevant in that repo |
| Tool API reference (URLs, IDs, quirks) | On-demand (skill or memory topic) | Only needed when working with that tool |
| Git conventions | Path-scoped rule (loads every session via paths: `**/.git*` or similar) | Effectively always-on but scoped if you want |
| Long reference docs (full API specs, deep examples) | Out-of-tier (`docs/`, not auto-recalled) | Only read explicitly |
| Active legal/sensitive directories | Hook (PreToolUse Write|Edit warning) | Must warn before edit |

## The MEMORY.md index pattern

`memory/MEMORY.md` is special: its first 200 lines auto-inject every session as your memory index. Use it as a pointer list, not as content:

```markdown
## Core Infrastructure & Rules
- [Core rules](core-rules.md) - execution auth, sync, security
- [LLM context best practices](llm_context_best_practices.md) - the research brief

## External Tools / APIs
- [Tool 1 reference](tool1.md) - call patterns, auth, quirks
- [Tool 2 reference](tool2.md) - ...
```

Claude sees this index every session. When it needs depth on a specific tool, it Reads the topic file. The topic file pays the cost only when needed.

**Anti-pattern:** putting tool content directly in MEMORY.md. Every session pays the cost of every tool reference, even ones unused that day.

## The skill activation puzzle

Skills (`.claude/skills/<name>/SKILL.md`) can auto-load when Claude judges the user's prompt matches the skill's `description` field. This is the cheapest path - skill body loads, no full memory file pulled.

But two competing mechanisms exist:

1. **Skill auto-activation** by description match (~250-400 chars of description listed every session)
2. **Auto-memory recall** which Claude Code uses to pull relevant memory files into context

In practice, auto-memory recall is more aggressive. If you have both a skill AND a memory file covering the same topic, auto-memory often wins. Three architectural choices:

### Memory-first (default in this template)
- Keep memory topic files small and focused (target: <200 lines each)
- Use skills as opt-in `/skill-name` shortcuts (set `disable-model-invocation: true`)
- Auto-memory becomes the single canonical path

**Pros:** reliable. **Cons:** higher per-query cost than skills when they trigger.

### Skill-first
- Delete the memory file pointer from MEMORY.md
- Skills become the only path for that domain
- Description-match drives loading

**Pros:** lowest per-query cost when matching works. **Cons:** when description matching fails, no fallback.

### Hybrid (no enforcement)
- Keep both, let Claude choose per query
- Description budget pays for the skill, MEMORY.md pointer pays for the memory file

**Pros:** flexible. **Cons:** doubles always-loaded cost for that topic.

This template defaults to **memory-first** because it's been validated as the more reliable pattern. See `memory/llm_context_best_practices.md` for the research.

## Hooks vs CLAUDE.md content

CLAUDE.md content is loaded with a "may or may not be relevant" disclaimer wrapping it. Claude treats it as suggestive. A rule like "never commit secrets" in CLAUDE.md is followed... mostly.

Hooks inject as clean `system-reminder` messages. No disclaimer. Claude treats them as authoritative.

So:

| Rule kind | Where to put it |
|-----------|----------------|
| "Pattern I prefer" (style, formatting) | CLAUDE.md |
| "Convention specific to this project" | CLAUDE.md |
| "Must NEVER happen" (commit secrets, push to main without build, edit legal/) | Hook |

The template's hook stack covers the "must NEVER" category:

- **SessionStart** - build authorization reminder every session
- **PreCompact** - re-inject your hard rules right before context summarization (otherwise they get summarized away)
- **PreToolUse Bash** - warns on `git add -A`, force push, reset --hard
- **PreToolUse Write|Edit** - warns before edits to sensitive paths (legal/, .env, settings.json)
- **PreToolUse Agent** - pre-spawn checklist for token efficiency
- **PreToolUse MCP list/search** - probe-before-pull discipline
- **PostToolUse Bash** - deployment reminder after git push
- **PostToolUse Write|Edit** - docs-sync reminder after relevant edits
- **Stop** - end-of-turn uncommitted-changes check

5 of these 9 ship as `.template` files - they need your project's specifics filled in.

## Cross-PC sync model

Everything in `~/.claude/` that should sync between PCs is a junction (directories) or link (settings.json file) pointing into this repo:

```
~/.claude/
├── CLAUDE.md                            -> imports memory/core-rules.md (one-liner)
├── settings.json                        -> link to claude-config/settings.json
├── commands/                            -> junction to commands/
├── skills/                              -> junction to skills/
├── rules/                               -> junction to claude-config/rules/
├── hooks/                               -> junction to claude-config/hooks/
└── projects/<encoded>/memory/           -> junction to memory/
```

`bootstrap.ps1` creates all of these. They survive `git pull` (the link target's content updates, the link itself doesn't change).

Caveat: hard links (which bootstrap uses when symlinks aren't available) can break on atomic-rename file saves. See `memory/hooks_sync_pattern.md` for details and the Developer Mode mitigation.

## See also

- [`memory/llm_context_best_practices.md`](../memory/llm_context_best_practices.md) - the research this architecture is based on
- [`memory/hooks_sync_pattern.md`](../memory/hooks_sync_pattern.md) - the link-vs-junction detail
- [`docs/why-this-pattern.md`](why-this-pattern.md) - rationale + key findings condensed
