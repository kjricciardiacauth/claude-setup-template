---
name: example-skill
description: REPLACE this description with a prescriptive trigger sentence for YOUR skill. Use when the user asks about <topic>, mentions <keyword1>, <keyword2>, <keyword3>, or wants to do <action>. Critical keywords drive auto-activation - list the actual words users naturally type.
disable-model-invocation: true
---

# Example Skill - Annotated Template

This is an annotated example showing how to write a skill. Delete this directory after reading it and create your own skills following the same pattern.

## Frontmatter explained

```yaml
---
name: example-skill                   # must match the directory name
description: <prescriptive sentence>  # what + when. Lists keywords that drive auto-activation.
disable-model-invocation: true        # hides from auto-activation; only /example-skill invocation
---
```

### `name`
Lowercase, hyphens. Must match the directory name. This becomes the slash command: `/example-skill`.

### `description`
The most important field. Up to 1,536 characters but practical sweet spot is 250-400. Use the prescriptive pattern:

> "What this skill is. Use when the user asks about X, Y, Z, or wants to do A, B, C."

Bad: "Reference for tool X." (descriptive, no trigger keywords)
Good: "Tool X operations. Use when the user asks about tool X, mentions <feature1>, <feature2>, or wants to <action>." (prescriptive, keyword-rich)

### `disable-model-invocation` (optional)
Set to `true` to hide this skill from Claude's auto-invocation. The skill stays available via `/example-skill` but doesn't compete for description budget.

This template ships with the example skill set to `disable-model-invocation: true` so it doesn't pollute YOUR description budget.

## Body content

Below the frontmatter, write the operational reference Claude needs when this skill is active. Keep it focused:

### Section 1: Critical facts

What Claude needs to know to do this task correctly.

- Fact 1: <example>
- Fact 2: <example>

### Section 2: Common commands / patterns

Code snippets, command examples, JSON shapes.

```python
example_call(param1="value", param2=42)
```

### Section 3: Gotchas

Non-obvious failure modes Claude should avoid.

1. Gotcha: <example>
2. Gotcha: <example>

### Section 4: Pointers to depth

```
For full API reference: docs/tool-references/<tool>.md
For historical changes: CHANGELOG.md
```

## How to test if your skill triggers

1. Save the SKILL.md
2. Start a fresh Claude Code session (skills are loaded at session start)
3. Type a prompt that matches your description keywords
4. Watch whether Claude invokes the skill (will appear in the response or skill-load indicator)

If it doesn't trigger:
- Description keywords don't match the user's natural phrasing -> rewrite description more prescriptively
- Description budget is overflowing -> raise `skillListingBudgetFraction` in settings.json
- Confused with auto-memory recall pulling a memory file instead -> check `memory/llm_context_best_practices.md` for the memory-first vs skill-first trade-off discussion
