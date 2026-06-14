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
