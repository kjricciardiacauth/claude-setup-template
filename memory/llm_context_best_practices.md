# LLM Context Best Practices Brief
**Research date:** 2026-05-23 | **Scope:** Optimal repo/memory organization for Claude Code
**Sources:** Anthropic official docs, community research, practitioner write-ups, adjacent frameworks

---

## 1. Context Architecture - The Layered Model

The proven pattern is four tiers, each with a specific purpose and loading behavior:

| Tier | What | Load timing | Target size |
|------|------|------------|-------------|
| **Always-on** | `~/.claude/CLAUDE.md` -> imports `core-rules.md` | Every session | <=80 lines |
| **Project-scoped** | `repo/CLAUDE.md` | When that repo is open | <=120 lines |
| **Path-scoped** | `.claude/rules/*.md` with `paths:` frontmatter | Only when matching files are active | Any |
| **On-demand** | Skills (`.claude/skills/`), memory topic files | When invoked or referenced | Any |

**Key insight:** Claude Code wraps CLAUDE.md content with a "may or may not be relevant" disclaimer. This is unavoidable. The only way to make rules *mandatory* is to put them in **hooks** - those inject as clean `system-reminder` messages with no disclaimer framing. Use CLAUDE.md for context; use hooks for compliance.

---

## 2. CLAUDE.md Design

### Size limits are real and hard
- **Anthropic official:** "Bloated CLAUDE.md files cause Claude to ignore your actual instructions"
- **Research (2025):** Instruction compliance decays linearly. Claude Sonnet achieves <30% perfect instruction following in agent scenarios when instructions exceed ~150
- **DeployHQ:** "If your config is over 500 lines, most is being ignored." Soft limit: ~300 lines
- **Community consensus:** 80 lines is the practical sweet spot; 120 is acceptable; 200 is the breaking point

### The pruning test (Anthropic's exact words)
> *"For each line, ask: 'Would removing this cause Claude to make mistakes?' If not, cut it."*

### What belongs where
| Content type | Where it goes |
|-------------|--------------|
| Non-obvious bash commands | CLAUDE.md |
| Project-specific conventions | CLAUDE.md |
| Common gotchas / quirks | CLAUDE.md |
| Rules that must NEVER be broken | **Hooks** (not CLAUDE.md) |
| Domain-specific knowledge | **Skills or memory topic files** (on-demand) |
| Full API documentation | External link or `docs/` folder |
| Tool-count inventories | **Memory file, not CLAUDE.md** |
| Workflow procedures | Memory topic file |
| Things that change frequently | Memory file with `last_updated` |

### Import pattern
```markdown
@path/to/detailed-rules.md

# Only what's truly non-importable here
```

---

## 3. Memory File Design

### The flat list problem
A flat MEMORY.md with 40+ entries requires Claude to scan the entire file to determine relevance. This wastes tokens and causes important entries to be missed under context pressure.

**Fix: Domain section headers.**
```markdown
## Core Infrastructure & Rules
## External Tools / APIs
## Operations / Workflows
## Reference
```

### File size targets
- **MEMORY.md (index):** First 200 lines auto-injected every session. Keep under 200 lines. Use as an index with one-line pointers to topic files - not the topic content itself.
- **Topic files:** No size limit - they load on demand. This is where real content lives.
- **Topic file naming:** Be specific. `hcp_tool.md` beats `tools.md`. Claude infers what's inside from the name alone.

### Dual-memory architecture
Best practice separates shared vs. personal memory:
- **Git-committed topic files** - shared across machines, versioned
- **Session-local auto-memory** - machine-specific, not committed

### Staleness is worse than absence
> *"Wrong instructions are worse than none"* - DeployHQ

Every memory file should include a `last_validated:` timestamp. Stale facts actively mislead Claude. Add frontmatter or a comment header:
```markdown
<!-- version: 1.2 | last_validated: 2026-05-23 -->
```

---

## 4. Repo Doc Organization - Multi-Repo Pattern

### The Virtual Monorepo pattern
For 4+ related repos, the best-practice pattern (Zanzal, 35-repo systems):

**System-map CLAUDE.md at the primary/workspace repo:**
- Documents how repos *relate* to each other
- What data flows between them
- Which repo owns which domain
- Not what individual code does - that's for per-repo CLAUDE.md

### Per-repo CLAUDE.md scope
Each repo gets its own CLAUDE.md scoped ONLY to that repo. Keep them short (under 120 lines). Use `@import` to pull shared rules.

### AGENTS.md as universal layer
AGENTS.md is the tool-agnostic layer (Claude Code, Cursor, Codex CLI, Aider all read it).
- **`AGENTS.md`** at each repo root = universal source of truth for that repo
- **`CLAUDE.md`** = Claude-specific additions only (imports from AGENTS.md or adds Claude-specific notes)

---

## 5. Tool Reference Patterns - Documenting External APIs for LLMs

### The quickref pattern
For tools with IDs that change (board/list/label IDs, pipeline IDs, employee IDs):

```markdown
# <Tool> Quickref
<!-- last_validated: YYYY-MM-DD -->

## <Resource Name>
ID: <id>
Sub-resources:
  Name 1: <id>
  Name 2: <id>
```

Eliminates 3-6 API probe calls burned at the start of every session that needs those IDs.

### ID documentation rules
1. List IDs alongside human-readable names - names for humans, IDs for the API
2. IDs in docs AND memory - don't make Claude look them up
3. Version stamp everything - `<!-- last_validated: YYYY-MM-DD -->` at the top
4. Never inline full API documentation - link to it; store supplementary docs in `docs/`

---

## 6. Cost Optimization - Proven Techniques

### Skills with auto-activation
Skills (`.claude/skills/<name>/SKILL.md`) load on demand when their `description` field matches the user's prompt keywords. Write descriptions prescriptively ("Use when the user asks about X, Y, Z") not descriptively ("Reference for X").

### Auto-memory recall vs skill activation
Both mechanisms exist in Claude Code:
- **Skill auto-activation:** description matching, fires when Claude picks up trigger keywords
- **Auto-memory recall:** Claude Code pulls memory files based on relevance

Auto-memory tends to be more aggressive. If you have both a skill and a memory file covering the same topic, auto-memory often wins. Two architectures:
- **Memory-first:** memory files (trimmed) are the canonical path, skills as opt-in `/skill-name` shortcuts
- **Skill-first:** delete MEMORY.md pointers for tools with skills, force skill-only routing

Memory-first is more reliable; skill-first is more token-efficient per query when it triggers.

### Subagents for research
Subagents run in their own context window and report back summaries. For multi-file exploration - use subagents. Main conversation context stays clean.

### Path-scoped rules
`.claude/rules/<name>.md` with `paths:` frontmatter only loads when matching files are active. Use for rules that only apply in a specific directory.

### /compact and /clear discipline
Between unrelated tasks, `/clear` resets context. Especially valuable after a big read session before switching to code.

---

## 7. Anti-Patterns - What Commonly Goes Wrong

| Anti-pattern | Why it hurts | Fix |
|-------------|-------------|-----|
| CLAUDE.md > 200 lines | Instructions lost in noise; compliance decays | Prune to 80 lines; move domain content to skills/memory |
| Flat MEMORY.md with 40+ entries | Scan cost; signal buried | Domain section headers; index-first structure |
| Same info in 3 files | Drift; stale in 2 of 3 | Single source of truth + pointer imports |
| Rules for must-happen behavior in CLAUDE.md | Advisory, not enforced | Use hooks instead |
| Full API docs inlined | Context bloat on every read | Link externally; store in `docs/` |
| Tool IDs not documented (probe calls required) | 3-6 API calls burned per session | Quickref files with validated IDs |
| Stale counts/versions in context | Actively misleads Claude | `last_validated:` timestamp + update discipline |
| Generic statements ("write clean code") | Wastes tokens, Claude ignores | Delete without mercy |
| File-by-file descriptions in CLAUDE.md | Claude can read the files | Delete without mercy |
| Memory files without domain metadata | Can't tell staleness | Add header with `version:`, `last_validated:` |
| Research in main conversation context | Context fills fast | Subagents for multi-file exploration |

---

## 8. Key Numbers to Remember

| Metric | Value | Source |
|--------|-------|--------|
| CLAUDE.md sweet spot | 80 lines | Community consensus |
| CLAUDE.md hard ceiling | 200 lines | Research (2025) |
| MEMORY.md auto-inject | First 200 lines | Anthropic official |
| Instruction compliance at 150+ | <30% perfect | Research |
| Hook injection cost | ~15 tokens/turn | Practitioner measurement |
| Skill description budget (default) | 1% of context window | Anthropic settings.json |
| Skill description budget (raised) | 2% if you have 10+ skills | `skillListingBudgetFraction: 0.02` |
