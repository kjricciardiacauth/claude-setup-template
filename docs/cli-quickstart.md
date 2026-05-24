# CLI Quickstart - Workflows Using the Tier 1 + Tier 2 Tools

After `install-cli.ps1` runs, you have 12 new tools on PATH. This doc shows what they replace and the common workflows where they shine.

## Tier 1 - the foundation

### rg (ripgrep) - search code instead of grep / Select-String

```powershell
# Find every TODO across the project
rg "TODO" src/

# Search only JS files
rg "useState" -t js

# Search but ignore tests
rg "deprecated" -g '!**/test/**'

# Show context (3 lines before + after match)
rg "fetch" -C 3 src/

# Case-insensitive search
rg -i "warning" logs/

# Show files containing match (paths only, no line content)
rg -l "Config" .
```

Replaces: `Select-String -Path *.js -Pattern "..."`, `Get-ChildItem -Recurse | Select-String`

### fd - find files instead of Get-ChildItem -Recurse

```powershell
# Find every README in the project
fd README

# Find .json files in a specific dir
fd -e json src/

# Find files modified in last 7 days
fd --changed-within 7d

# Find and execute on each match (delete .tmp files)
fd -e tmp -X rm

# Find directories only
fd -t d node_modules
```

Replaces: `Get-ChildItem -Recurse -Filter`

### bat - cat with syntax highlighting

```powershell
# View a single file with line numbers + syntax
bat config.json

# Multiple files (uses ranges)
bat README.md package.json

# Pipe to bat to highlight
git diff | bat -l diff

# No paging (output direct to terminal)
bat -pp config.json
```

Replaces: `Get-Content`, `cat`

### fzf - interactive fuzzy finder

```powershell
# Pick a file interactively
fzf

# Pipe a list to fzf, get the selection back
git branch | fzf

# Common pattern: git checkout via fzf
$branch = git branch --all | fzf
git checkout $branch.Trim()

# Find and open a file in $EDITOR
$file = fzf
code $file

# In the prompt, type to filter. Tab to multi-select.
```

Pairs well with rg/fd:
```powershell
# Fuzzy-find files matching a pattern, then preview
fd .py | fzf --preview "bat {}"
```

### jq - JSON queries instead of ConvertFrom-Json filters

```powershell
# Extract a single field
echo '{"name":"Alice","age":30}' | jq .name

# Filter array
echo '[{"x":1},{"x":2}]' | jq '.[] | select(.x > 1)'

# Pretty-print
curl -s api.example.com/data | jq

# Map / transform
cat data.json | jq '.users | map({name: .name, email: .email})'

# Get raw string (no quotes)
echo '{"name":"Alice"}' | jq -r .name
```

Replaces: `ConvertFrom-Json | Where-Object | Select-Object`

### xh - HTTP client (curl replacement)

```powershell
# GET
xh GET https://api.github.com/users/octocat

# POST JSON body
xh POST api.example.com/items name=widget price:=42

# With headers
xh GET api.example.com authorization:"Bearer $token"

# Streaming response
xh --stream GET api.example.com/events

# Save response body to file
xh GET https://example.com/file.zip -o file.zip
```

Replaces: `Invoke-RestMethod`, `Invoke-WebRequest`, `curl`

### zoxide - jump to directories you've visited

```powershell
# First visit (use cd as normal)
cd C:\Users\Admin\projects\my-app

# Later, from anywhere:
z my-app

# Partial match works too
z app

# Multiple matches: interactive picker
z proj    # opens fzf-style picker if ambiguous

# Show ranked history
zoxide query --list
```

Replaces: typing full paths to `cd`.

## Tier 2 - situational

### lazygit - terminal UI for git

```powershell
lazygit
```

Launches a full-screen TUI. Stage hunks interactively, write commits, view diffs, rebase, push/pull - all via keyboard. Worth learning if you do partial-hunk staging or interactive rebases often.

### gron - flatten JSON for grep

```powershell
# Convert nested JSON to greppable lines
curl -s api.example.com/data | gron

# Output looks like:
# json.users[0].name = "Alice";
# json.users[0].email = "alice@example.com";

# Now grep into deeply nested structures
curl -s api.example.com/data | gron | rg "email.*@gmail"

# Reverse: convert flat lines back to JSON
curl -s api.example.com/data | gron | rg "email" | gron --ungron
```

Use when JSON is too nested for `jq` to be quick to write.

### uv - Python package management

```powershell
# Install a tool globally
uv tool install ruff

# Create + activate a venv for a project
uv venv
.venv\Scripts\Activate.ps1

# Install dependencies (replaces pip + venv)
uv pip install requests
```

Replaces the pip/venv/poetry/pipx mess for Python project setup.

### starship - cross-shell prompt

After install, the PowerShell profile block in `install-cli.ps1` adds:
```powershell
Invoke-Expression (& { (starship init powershell | Out-String) })
```

You get a prompt showing: cwd, git branch + status, language version (py, node), and more. Configure via `~/.config/starship.toml`.

### gh-dash - terminal dashboard for GitHub

```powershell
gh-dash
```

TUI showing your PRs, issues, notifications across all repos. Useful if you have >1 active PR at a time.

## Composing the tools

The point of the Tier 1 set is they compose:

```powershell
# Find all JSON files, show their top-level keys
fd -e json . | ForEach-Object { Write-Host "=== $_ ==="; jq 'keys' $_ }

# Find files with TODO, pick one interactively, open it
$f = rg -l "TODO" | fzf --preview "rg --color=always TODO {}"
code $f

# Show all worker URLs across the project's JSON configs
fd wrangler.toml -X cat | rg "url ="

# Test an API endpoint, pretty-print response
xh GET api.example.com/health | jq

# Search git log for a keyword, pick one, show the commit
$sha = git log --oneline | fzf | ForEach-Object { ($_ -split ' ')[0] }
git show $sha
```

## Claude integration

The template's `claude-config/settings.json` pre-approves these tools in the `permissions.allow` array:

```json
"permissions": {
  "allow": [
    "Bash(rg:*)", "Bash(fd:*)", "Bash(bat:*)", "Bash(fzf:*)",
    "Bash(jq:*)", "Bash(xh:*)", "Bash(zoxide:*)", "Bash(z:*)"
  ]
}
```

Claude can use these without per-call permission prompts. Helpful for:

- "Find all files mentioning X" -> `rg X`
- "Show me what's in this JSON" -> `cat file.json | jq`
- "Probe this API endpoint" -> `xh GET ...`
- "Jump to that project I was working on" -> `z <name>`

## See also

- `memory/cli_toolset.md` - the why and the package manager policy
- `install-cli.ps1` - the installer script
