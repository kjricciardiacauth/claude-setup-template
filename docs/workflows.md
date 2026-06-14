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
