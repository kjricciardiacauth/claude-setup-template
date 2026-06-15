# Design — Comprehensive Craft Upgrade for claude-setup-template

**Date:** 2026-06-14
**Status:** Approved (design); pending implementation plan
**Repo:** `claude-setup-template` (public, MIT)

## North star

A user points Claude Code at this repo and their experience gets better — immediately, with
no editing required for the universal parts. Every artifact is judged against one question:
*"Does this improve a cold stranger's session out of the box, and is its principle still valid
even when the artifact ships inert?"*

## Background

The template's first cut (bootstrap, a 6-hook stack, `memory/`, `docs/`, `skills/`,
cross-platform settings) is solid but early. A large body of operating craft has matured since
in a separate **private** working environment and is not reflected here. This upgrade ports the
**patterns** — generalized and sanitized — not the private content. The private environment is
the *source of lessons*, never copied verbatim.

## Scope boundary + sanitization contract

**What crosses (generalized, project-agnostic):** enforcement *patterns* (hooks), generic
*rules*, distilled *lessons*, and *workflow* integration. Anything user-specific ships as a
graceful-no-op `.template` with placeholders, and its principle is documented regardless.

**What never crosses (hard boundary):** any private/business memory file; account-coupled hooks;
and any proper noun or identifier — organization names, personal names, usernames, account
emails, third-party SaaS/tool names tied to a specific account, channel IDs, customer data,
tokens/keys, or reverse-engineering internals.

**Sanitization gate (hard, enforced before every commit):** a denylist grep for those
proper nouns/identifiers must return **zero hits**. A private-derived artifact is only allowed
across after it has been rewritten into a placeholdered, project-agnostic form that passes the
grep. This is the central risk of porting private → public and is treated as a blocking gate,
not a guideline.

**Cross-cutting build rules** (inherited from the repo's existing standards): every hook ships in
both `.ps1` and `.sh`; ASCII-only punctuation (the PowerShell cp1252 gotcha); user-specific hooks
ship inert as `.template`; the README "What to customize" table and platform matrix are updated
for every new file.

## Phase 1 — port the substance (additive, sanitized)

Default-active artifacts are universal and safe with no user config. `.template` artifacts need a
user-specific value and no-op gracefully until filled in.

### A. Hooks (`claude-config/hooks/`, each `.ps1` + `.sh`, wired in both settings files)

| Hook | Principle | Default |
|---|---|---|
| `stop-verify-gate` | Verification-before-completion: on a state-changing turn, require verifying against fresh reads before claiming done. Generic buckets: external writes / sends / file edits / git / deploy. | **Active** |
| `pre-write-secrets-scan` | Flag secret-looking strings (keys, tokens) in content about to be written. | **Active** |
| `pre-bash-github-identity` | Per-repo identity: warn on `gh auth switch` (machine-global, races sessions) and on bare `github.com` origins that should embed an account. | **Active** |
| `session-activity-logger` | Local, **gitignored** cross-session "recent activity" feed so concurrent sessions don't duplicate work. | **Active** |
| `stop-board-gate` | If a project board/registry is configured, require a board update when shipping; otherwise no-op. | `.template` |

### B. Rules (`claude-config/rules/`, generalized)
- `github-rules.md` — board + identity discipline at the principle level.
- `github-projects.json.template` — registry schema with an empty/example entry.
- `workers.md` — generic Cloudflare Worker deploy conventions: resolve account from OAuth (never
  hardcode an account ID), don't deploy while live consumers are connected, keep every change
  backward-compatible across deployed client versions.

### C. `docs/best-practices.md`
The distilled lessons as project-agnostic principles, each with the *why*:
explicit-build authorization · verification-before-completion · probe-before-pull (sample any
list/query tool small before a large pull) · debugging discipline (match the working reference
exactly before deviating · demand positive proof before blaming the environment · stop and
question fundamentals at 3 failed fixes) · git sync-check before push · present options to pick
rather than guessing · the multi-page-PDF extraction workaround · token-efficient agent spawning
(hard caps, prefer direct tools under ~10 calls) · no unbounded research loops.

### D. `docs/workflows.md`
The structured-workflow chain (brainstorm → plan → execute → finish, plus
verification-before-completion, systematic-debugging, TDD, and worktree-based parallel lanes),
*referenced and recommended* (not vendored — it's a separate plugin), plus the generalized
parallel-lane worktree-dispatcher pattern (independent segments on non-overlapping files run as
isolated worktree branches to a gate-stop; one owner serializes the merges).

### E. `core-rules.md.template` upgrade
Fold the matured always-on disciplines into the shipped starter: build-authorization,
verification-before-completion, caution before irreversible/outward-facing actions, debugging
discipline, and security basics (secrets never in repos, never echo credentials into chat).

## Phase 2 — the guide spine (connective, lighter; after Phase 1)

A top-level `GUIDE.md` — a "supercharge your setup" curriculum: Fundamentals → Tools → Hooks →
Rules → Best Practices → Workflows. Each section is a short intro that links into the concrete
artifacts. The README points to it, turning the repo from a parts-bin into a teaching resource.

## Delivery, safety, testing

- **Sanitization grep gate:** denylist returns zero hits before every commit (blocking).
- **Two plans:** each phase gets its own implementation plan; Phase 1 ships first.
- **Cross-platform parity + ASCII:** every hook in `.ps1` and `.sh`; README "What to customize"
  table and platform matrix updated per new file.
- **Hook smoke-check:** each hook runs clean as a no-op on representative sample input
  (it must never hard-error a turn).
- **Doc link-check:** internal links in the new docs/guide resolve.
- **North-star check per artifact:** improves a cold session out of the box; principle valid even
  when inert.

## Success criteria

1. A fresh clone, pointed at by Claude Code with no edits, yields measurably better default
   behavior (verification gate, secrets scan, identity guard, activity feed all active and
   no-op-safe).
2. Every new principle is documented and accessible even where its hook ships as a `.template`.
3. Sanitization grep gate passes (zero proper-noun/identifier hits) on the full diff.
4. Cross-platform parity holds; no hook hard-errors a turn on any platform.
5. Phase 2 `GUIDE.md` gives a newcomer a single front-door reading path.

## Out of scope

- Any private/business memory files, account-coupled hooks, or third-party-tool integrations
  tied to a specific account.
- Vendoring the external workflow plugin (we reference it, not bundle it).
- Restructuring the existing working bootstrap/CLI installers beyond what new files require.
