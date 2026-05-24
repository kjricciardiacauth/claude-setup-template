# Skills - On-Demand Reference Loaded by Claude

Skills are scoped reference docs that Claude loads when relevant. Unlike CLAUDE.md content (loaded every session), a skill's body is only injected when Claude decides the skill matches the current task.

**Two activation paths:**

1. **Auto-activation by description match.** When the user's prompt contains keywords matching a skill's `description` field, Claude auto-invokes it. *Reliability varies* - see "Lesson learned" below.

2. **Manual invocation with `/skill-name`.** The user types `/your-skill-name` and Claude loads that skill's body.

## How to author a skill

Every skill is a directory under `skills/` containing a `SKILL.md` file:

```
skills/
  my-skill/
    SKILL.md
```

The `SKILL.md` must have YAML frontmatter:

```markdown
---
name: my-skill
description: One sentence describing what + when. Use prescriptive trigger phrases listing keywords the user would naturally type.
---

# My Skill - Operational Reference

(body content - facts, commands, examples Claude needs when this skill loads)
```

## The big lesson on `description`

**Write descriptions prescriptively, not descriptively.**

### Bad (descriptive - what's in the skill)
```yaml
description: HouseCall Pro MCP reference - worker URL, token auth, tool inventory, quirks
```

### Good (prescriptive - WHEN to use the skill, with concrete keywords)
```yaml
description: HouseCall Pro (HCP) operations and MCP quirks. Use when the user asks about HCP, HouseCall Pro, jobs, list_jobs, list_invoices, dispatch, schedule, employee IDs, technicians, work orders, money in cents, HCP auth token, HCP worker URL, or wants to call any HCP MCP tool.
```

In testing, descriptive descriptions failed to auto-trigger on real user prompts ("what's our HCP auth?"). Prescriptive descriptions with explicit "Use when..." + keyword lists succeeded.

## Hiding skills from auto-activation

If a skill is purely user-invocable (slash-command-only, you don't want Claude to auto-load it), add this to the frontmatter:

```yaml
disable-model-invocation: true
```

The skill stays available via `/skill-name` but is removed from the description listing budget (~250-300 chars saved per skill in every session's always-loaded context).

## Description listing budget

By default, the skill description listing gets 1% of the context window. With 10+ skills active, that fills up and descriptions get truncated, stripping the keywords that drive auto-activation. The template raises this to 2% in `claude-config/settings.json`:

```json
{
  "skillListingBudgetFraction": 0.02
}
```

Run `/doctor` (if available in your Claude Code build) to check if the budget is overflowing.

## When to author a skill vs add to memory

| Use case | Where it goes |
|----------|--------------|
| Domain reference that's relevant to one specific task type | **Skill** |
| Always-true fact about your project | Memory (topic file) |
| Multi-step procedure that gets invoked occasionally | **Skill** with `/skill-name` invocation |
| Reference you want pinned to the slash menu | **Skill** |
| Reference you want Claude to find via MEMORY.md index | Memory (topic file) |

Both patterns coexist. The memory-first architecture in this template uses MEMORY.md pointers as the primary discovery path; skills as opt-in `/skill-name` shortcuts. See `memory/llm_context_best_practices.md` for the architectural rationale.

## Example

See `example-skill/SKILL.md` in this directory for an annotated example showing all the pieces.
