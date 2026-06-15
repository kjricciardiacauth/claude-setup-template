# Phase 1c: Best-Practices + Workflows Docs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two project-agnostic reference docs that distill the operating lessons behind this template — `docs/best-practices.md` (principles + the why) and `docs/workflows.md` (the structured workflow chain + parallel lanes) — and surface them from the README.

**Architecture:** Pure markdown docs under `docs/`. No code, no hooks, no settings. Verification is sanitization + internal link-check. Each doc stands alone; the README gets a short pointer to both.

**Tech Stack:** Markdown.

---

## File Structure

| File | Responsibility |
|---|---|
| `docs/best-practices.md` | The distilled operating principles, each with a one-line "why". |
| `docs/workflows.md` | The structured workflow chain (recommended external plugin) + the parallel-lane worktree pattern. |
| `README.md` | MODIFY: link both new docs from the existing "Architecture overview" / "Related reading" area. |

---

## Task 1: docs/best-practices.md

**Files:** Create `docs/best-practices.md`

- [ ] **Step 1: Write the file** (ASCII-only)

````markdown
# Best Practices

The operating principles this template encodes. Each is a habit that pays off across real, long sessions -
the hooks enforce some of them; the rest are yours to keep. Project-agnostic: adapt the specifics, keep the principle.

## Plan first, act on "go"
Default to planning, design, and discussion. Don't write code, edit files, or run state-changing commands until
the human explicitly approves ("build" / "go" / equivalent). The cost of a wrong assumption acted on early is far
higher than the cost of confirming first. (Re-confirm after any context reset.)

## Verify before you claim done
A successful tool call (exit 0, HTTP 200) proves the call *ran*, not that the resulting *state* is correct. Before
saying done / fixed / sent / passing:
- **External writes** (a record in a DB / CRM / API) -> re-fetch and confirm the field actually changed.
- **Sends** (email / chat / SMS) -> confirm it left as SENT; if only staged, say "drafted, not sent".
- **File edits** -> re-read the changed region; for a fix, show the check or test output that proves it.
- **git / build / deploy** -> show the real output (commit hash, deploy id, push result), not an assumption.
State the evidence first, then the claim.

## Probe before you pull
Before a large `list`/`search`/query against an unfamiliar API or tool, request the smallest page first. Confirm
the response shape and the total count, then pull a calibrated amount. A blind large pull wastes context and can
hammer a rate limit you could have avoided.

## Debugging discipline
- **Match the working reference exactly before deviating.** If a known-good example exists, diff against it and
  change ONE variable at a time. Don't add cleverness it lacks.
- **Don't blame the environment without proof.** "Rate limit" / "flaky network" / "throttled" needs POSITIVE
  evidence. Run the cheapest test that would DISPROVE your hypothesis before chasing it.
- **Count your fixes. At three failed fixes, STOP** and question the fundamentals - you're probably wrong about
  the cause, not one tweak away. Re-read the error; form a new hypothesis; test that.

## Git hygiene
- **Stage specific files** - never `git add -A` / `git add .` (you'll eventually stage a secret or junk).
- **Sync-check before push:** full `git fetch` then `git status` (no `--quiet`/`--short`, which hide the
  ahead/behind line).
- **Roll back with `git revert`** (a new commit), not `git reset --hard` on shared history.

## Present options; don't guess
When a decision is genuinely the human's to make and you can't resolve it from context, lay out the concrete
options and let them pick - don't silently guess and build the wrong thing. For choices with an obvious default,
state the default and proceed.

## Token-efficient delegation
- Prefer direct tools for small tasks. A handful of tool calls rarely justifies spawning an agent.
- When you do spawn an agent, give it **hard caps** ("max N tool calls, stop at N, return what you have") - soft
  limits get ignored - and pick the cheapest model that can do the job.
- Cap research: bound the number of searches/fetches and return at the cap rather than looping unboundedly.

## Read PDFs correctly
Naive text extraction silently fails on multi-page or image-only PDFs. Probe first (does any text come out?); use a
real extractor (`pdftotext`) for text PDFs and an OCR pass for image-only ones. Never answer from a partial extract.

## Security basics
Secrets live in environment variables / a secret manager / your platform's encrypted config - never committed to a
file or pasted into chat (transcripts persist). Never fabricate an unknown identifier or token; fetch it from an
authoritative source or ask. (The `pre-write-secrets-scan` hook backstops this.)

## Memory hygiene
Keep always-on context lean - a short rules file plus an index, with detail in on-demand topic files loaded only
when relevant. Big always-loaded context dilutes attention; small + well-indexed beats large + flat.
````

- [ ] **Step 2: Commit**

```bash
git add docs/best-practices.md
git commit -m "docs: best-practices reference (distilled operating principles)"
```

---

## Task 2: docs/workflows.md

**Files:** Create `docs/workflows.md`

- [ ] **Step 1: Write the file** (ASCII-only)

````markdown
# Workflows

How to run substantive work so it stays correct and reviewable. These pair with the hooks in this template (the
verification gate, the activity ledger) but are useful on their own.

## The chain: brainstorm -> plan -> execute -> finish
Substantive features and bugfixes go through four phases. Trivial edits skip it - but say which step you skipped.

1. **Brainstorm** - explore intent, constraints, and trade-offs BEFORE writing code. Produce a short written
   spec and get agreement on it. The cheapest place to fix a design is before it exists.
2. **Plan** - turn the spec into a bite-sized, ordered task list with exact files and verification per task.
   Write it down; a plan you can check off is a plan you can hand off or resume after a context reset.
3. **Execute** - implement task by task, smallest viable change first, verifying each before moving on. Commit
   frequently with specific staging.
4. **Finish** - verify the whole, then decide integration deliberately: merge, open a PR, or hold. Don't let
   "done" be implicit.

Two disciplines run throughout: **test-driven** (write the failing check first where it applies) and
**verification-before-completion** (evidence before any "done"). For bugs, run a **systematic-debugging** pass
(reproduce -> isolate -> form a falsifiable hypothesis -> test it) rather than guessing.

> This template doesn't bundle a workflow engine. The phases above map cleanly onto the open-source
> **superpowers** skill set for Claude Code (brainstorming, writing-plans, subagent-driven-development /
> executing-plans, verification-before-completion, systematic-debugging, test-driven-development,
> using-git-worktrees, finishing-a-development-branch). Install it if you want the phases as first-class skills;
> the principles hold either way.

## Parallel lanes (worktree fleet)
When work splits into 2+ segments that touch NON-overlapping files, run them as concurrent **lanes** instead of
serially:

- Each lane is its own `git worktree` on its own branch, built to a **gate-stop**: implement one segment, verify
  it, then STOP and report - leave the changes uncommitted (or on the lane branch) for review.
- One owner per "seam" (a file or module no other lane touches) so lanes never collide.
- A single **dispatcher** (you, or the human) owns the main branch, independently re-verifies each lane's gate
  report, and **serializes the merges** one at a time.

This buys wall-clock parallelism without merge chaos. The rule that makes it safe: **lanes never share a file.**
If two segments must touch the same file, they're one lane, not two.

## How the hooks support this
- The **activity ledger** (`session-log-*`) records what changed each turn, so a resumed or concurrent session
  can see recent work instead of re-doing it.
- The **verification gate** (`stop-verify-gate`) makes the "verify before done" step non-optional on any turn that
  changed state.
- The optional **board gate** (`stop-board-gate`) keeps a project board honest as the source of open work.
````

- [ ] **Step 2: Commit**

```bash
git add docs/workflows.md
git commit -m "docs: workflows reference (brainstorm->plan->execute->finish + parallel lanes)"
```

---

## Task 3: Link the docs from README + sanitization gate

**Files:** Modify `README.md`

- [ ] **Step 1: Add both docs to the README.** In the "Architecture overview" section (which already points to `docs/architecture.md` and `memory/llm_context_best_practices.md`), add a line so the new docs are discoverable. Add this sentence after that existing pointer (ASCII-only):

```markdown
See [`docs/best-practices.md`](docs/best-practices.md) for the operating principles this template encodes, and [`docs/workflows.md`](docs/workflows.md) for the brainstorm -> plan -> execute -> finish workflow and the parallel-lane pattern.
```

- [ ] **Step 2: Sanitization + link-check**

```bash
# Sanitization (want ZERO real leaks)
grep -niE "acauthority|kjricciardi|stoopkid|housecall|quickbooks|callrail|sunsama|bamboo|\bSTOOP\b|TL-DPS|trello|\bHCP\b|\bQBO\b" docs/best-practices.md docs/workflows.md && echo "!! LEAK !!" || echo "ZERO leaks"
# ASCII
grep -rPn "[^\x00-\x7F]" docs/best-practices.md docs/workflows.md README.md && echo "!! NON-ASCII !!" || echo "ASCII-clean"
# Link targets exist
for t in docs/best-practices.md docs/workflows.md; do [ -f "$t" ] && echo "ok link $t" || echo "MISSING $t"; done
```
Expected: `ZERO leaks`, `ASCII-clean`, 2 `ok link` lines.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: link best-practices + workflows from README"
```

---

## Self-review notes (author)

- **Spec coverage:** implements the spec's Phase-1 `docs/best-practices.md` and `docs/workflows.md`. Deferred: `core-rules.md.template` upgrade (1d), Phase 2 `GUIDE.md`.
- **Sanitization:** the lessons are written as generic principles (no org/account/tool proper nouns); the workflow doc references the external superpowers skill set by name (a public open-source project) but vendors nothing.
- **No code:** docs only; verification is sanitization + link-check, not behavioral tests.
````
