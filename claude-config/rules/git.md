# Git Conventions

## Commit Messages

Use PowerShell HEREDOC format:
```powershell
git commit -m @"
Short subject line (under 70 chars)

Detailed explanation if needed.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
"@
```

## File Staging

Never `git add -A` or `git add .` - risk of staging secrets or unrelated changes.

Always stage specific files:
```powershell
git add path/to/file.js path/to/other.md
```

## Direct-to-Main Policy

Solo work goes directly to `main` - no feature branches needed. Roll back with `git revert` (new commit), never `git reset --hard`.

## Sync Check

Always run full `git fetch` then `git status` before pushing. Never use `--quiet` or `--short` - those flags hide the behind/ahead line.
