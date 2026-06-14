# GitHub Projects + Identity Discipline

> Opt-in. Applies only to repos listed in `github-projects.json` (the registry). If you don't use GitHub
> Projects, ignore this file and leave `stop-board-gate` as a `.template`. Enforced by `stop-board-gate`
> (board) + `pre-bash-github-identity` (identity).

## The registry
- `claude-config/rules/github-projects.json` lists each repo that uses a GitHub Project, with its board number,
  owner, account, and path hints. **Adding a project = one entry** and the board gate picks it up automatically.
- Copy `github-projects.json.template` to `github-projects.json` and fill in your project(s).

## Board is the source of truth (any registered project)
- Open work lives on the repo's GitHub Project (number per the registry), not a scattered markdown TODO list.

## Card lifecycle (HARD)
- **Pick up** a card -> Status **In Progress**.
- **Finish** -> comment the evidence + **close with the commit hash** (`gh issue close <n> --comment "Fixed in <hash>"`) + Status **Done**.
- **New follow-up work** -> **create a card** rather than letting it vanish.
- Shipping work to a registered repo (commit / push / release / deploy) WITHOUT a board update -> `stop-board-gate` blocks the turn.

## Identity (HARD - all GitHub work)
- Remotes embed the account (`https://<account>@github.com/...`); a bare `https://github.com/...` origin is the bug.
- **Never `gh auth switch`** - it flips the machine-global active account and races concurrent sessions.
- The gh `project` scope must be present: `gh auth refresh -s project`.

## Process
- **Substantive** work runs the full workflow (brainstorm -> plan -> execute -> finish); trivial edits don't, but
  name the step you skipped. Verify against fresh reads before claiming completion, always.
