# CLI Toolset - Recommended Foundation for Claude Code Work

## What's installed (Tier 1)

Install via `install-cli.ps1 -Tier 1`. Reproducible across PCs.

| Tool | Replaces | winget ID | Common use |
|---|---|---|---|
| **rg** (ripgrep) | `Select-String`, native `grep` | `BurntSushi.ripgrep.MSVC` | `rg "TODO" src/` - search across code in <1s |
| **fd** | `Get-ChildItem -Recurse -Filter` | `sharkdp.fd` | `fd worker.js` - find files fast, smart-case |
| **bat** | `Get-Content`, `cat` | `sharkdp.bat` | `bat config.json` - syntax-highlighted view + paging |
| **fzf** | manual list scrolling | `junegunn.fzf` | `git log --oneline \| fzf` - pick a SHA interactively |
| **jq** | `ConvertFrom-Json \| Where-Object` | `jqlang.jq` | `xh GET ... \| jq '.items[0]'` - filter JSON |
| **xh** | `Invoke-RestMethod`, `curl` | `ducaale.xh` | `xh POST api.example.com tools=list` - probe REST APIs |
| **zoxide** | typing full `cd` paths | `ajeetdsouza.zoxide` | `z proj` jumps to `~/code/my-project` after one prior visit |

## Tier 2 - additional ergonomics

Install via `install-cli.ps1 -Tier 2`. Optional but useful.

| Tool | When you want it | Install |
|---|---|---|
| **lazygit** | Start doing partial-hunk staging or interactive rebases | winget |
| **gron** | A JSON response is too nested for `jq` to be quick | scoop |
| **uv** | Python project / venv churn (replaces pip/venv) | winget |
| **starship** | Want at-a-glance "which repo / which branch / which py venv" in pwsh | winget |
| **gh-dash** | >1 active PR you're tracking across repos at once | scoop |

Note: `gron` and `gh-dash` come from scoop because winget doesn't carry them. `install-cli.ps1` installs scoop only if needed.

## Skip list (don't install)

- **oh-my-posh** - starship covers the same ground, lighter and faster
- **chocolatey** - third package manager fragments install state, no upside over winget+scoop
- **WSL2 as primary shell** - PowerShell + Tier 1 tools cover Windows workflow cleanly. WSL only if a specific tool demands it
- **httpie (Python)** - xh has the same syntax, single Rust binary, no Python dependency drift
- **eza / lsd** - `Get-ChildItem` with tab-completion is fine, low payoff

## Package manager policy

**winget primary, scoop relief valve.** Winget is built into Windows 11, MS-backed, supports YAML export for reproducible setup, and carries every Tier 1 tool. Scoop only for genuine gaps (`gron`, `gh-dash`). No chocolatey - third PM = fragmentation. See `install-cli.ps1` for the idempotent install pattern.

## PowerShell profile additions

`install-cli.ps1` appends an idempotent block to `$PROFILE.CurrentUserCurrentHost` between marker lines:

```powershell
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (starship init powershell | Out-String) })
}
Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory
```

zoxide init is required for `z` to work. PSReadLine binding makes Ctrl+R behave like bash reverse-search (useful with fzf piped history workflows).

## Claude permissions

`claude-config/settings.json` has `permissions.allow` entries for `Bash(rg:*)`, `Bash(fd:*)`, `Bash(bat:*)`, `Bash(fzf:*)`, `Bash(jq:*)`, `Bash(xh:*)`, `Bash(zoxide:*)`, `Bash(z:*)` so Claude runs these without prompting. The settings file is linked into `~/.claude/settings.json` via `bootstrap.ps1`, so the permissions propagate.

## Verification

After `install-cli.ps1` run, manual smoke tests:

```powershell
rg --version              # 14+
fd Cargo.toml             # find files matching pattern
bat README.md             # syntax-highlighted view
echo '{"a":1}' | jq .a    # -> 1
xh GET https://api.github.com/zen
z proj                    # jumps to a path zoxide has seen before
```

## See also

- [`hooks_sync_pattern.md`](hooks_sync_pattern.md) - how `settings.json` is linked across PCs
- [`llm_context_best_practices.md`](llm_context_best_practices.md) - the layered context model
- `docs/cli-quickstart.md` - workflow examples replacing PowerShell-native commands with these tools
