# macOS / Linux Notes

The template fully supports Mac (and Linux best-effort). Most things work identically to Windows; this doc collects the Mac/Linux-specific details worth knowing.

## What's different vs the Windows path

| Concern | Windows | Mac/Linux |
|---------|---------|-----------|
| Bootstrap script | `bootstrap.ps1` | `bootstrap.sh` |
| CLI installer | `install-cli.ps1` (winget + scoop) | `install-cli.sh` (brew) |
| Hook script language | PowerShell `.ps1` | bash `.sh` (chmod +x required) |
| Settings file | `claude-config/settings.windows.json` | `claude-config/settings.mac.json` |
| Filesystem link | symlink (if Developer Mode) or hard link | symlink (always - no special privilege needed) |
| `~/.claude/...` paths | `%USERPROFILE%\.claude\...` | `$HOME/.claude/...` |
| Project-name encoding | `C:\Users\Admin` -> `C--Users-Admin` | `/Users/alice` -> `-Users-alice` |

The architectural pattern is identical. Only the implementation details differ.

## Homebrew on a fresh Mac

`bootstrap.sh` installs Homebrew if missing. This is the one-time interactive step:

- Will prompt for your sudo password (Homebrew installs to `/opt/homebrew` on Apple Silicon, `/usr/local` on Intel - both need sudo on first install)
- Takes 1-3 minutes
- Adds itself to your shell PATH automatically (script does `eval "$(brew shellenv)"` to use it immediately)

If you've already installed Homebrew via some other method, `bootstrap.sh` detects it and skips.

## Linux support is best-effort

`bootstrap.sh` detects `apt-get` (Debian/Ubuntu) and `dnf` (Fedora/RHEL) but the package names and availability vary by distro:

- `git`, `nodejs`, `npm` - widely available, should work on any reasonable distro
- `gh` (GitHub CLI) - requires adding GitHub's apt repo first on Debian/Ubuntu; script tells you the URL
- All the CLI tools - require Homebrew on Linux (which works but is heavier than native packages)

If you're on Linux and want native packages instead of brew, install manually:

```bash
# Debian/Ubuntu example
sudo apt-get install ripgrep fd-find bat fzf jq
# 'fd' is named 'fd-find' on apt; create alias: alias fd=fdfind
# 'bat' is named 'batcat' on apt; create alias: alias bat=batcat
# 'xh', 'zoxide' - get from cargo or brew
```

## Symlinks vs hard links

Mac/Linux always use symlinks (`ln -s`). No Developer Mode toggle needed - symlinks work on any user account without elevated privileges.

This means the "hard link breaks on atomic-rename" problem that affects Windows users does NOT affect Mac/Linux. Editing `claude-config/settings.mac.json` via any editor (including Claude Code's Edit tool) preserves the symlink.

## Shell profile changes

`install-cli.sh` appends a block to your shell profile:

- `$HOME/.zshrc` if it exists (Mac default since macOS Catalina)
- `$HOME/.bashrc` if no zshrc
- `$HOME/.bash_profile` as fallback

The block sets up zoxide, starship, and fzf reverse-history search. Run `source ~/.zshrc` (or open a new terminal) to apply.

## File permissions on hook scripts

Bash hook scripts require the executable bit. `bootstrap.sh` runs `chmod +x` on all `.sh` files automatically, but if you create a new hook script or unzip from an archive that strips perms:

```bash
chmod +x claude-config/hooks/*.sh
```

The Mac/Linux `settings.mac.json` invokes hooks as `bash "$HOME/.claude/hooks/<script>.sh"` so the exec bit isn't strictly required - but it's still good hygiene.

## Common issues

### "Operation not permitted" when ln -s

Usually means System Integrity Protection is blocking the operation, or you're trying to link inside a protected directory (`/usr/local` on Intel Macs without Homebrew permissions fixed). Workaround: install Homebrew first, then re-run bootstrap.

### `gh: command not found` after bootstrap on Linux

Some Linux distros (Debian/Ubuntu) require adding GitHub's apt repo before `gh` is available. `bootstrap.sh` tells you the URL but doesn't add the repo automatically (it requires sudo, which we don't want to assume). Manually:

```bash
type -p curl >/dev/null || sudo apt install curl -y
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh -y
```

### `npm error: EACCES` on Mac

Usually means you installed Node via the system package or .pkg, and npm is trying to write to a system-owned directory. Fix by setting npm prefix to a user-owned directory:

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
# Add to your shell profile:
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc
source ~/.zshrc
```

Then re-run `npm install -g @anthropic-ai/claude-code`.

Better: install Node via Homebrew (`brew install node`) which uses `/opt/homebrew` (no sudo required).

### "command not found" after install

After installing tools via brew or npm, the current shell's PATH cache may be stale. Either:

- Open a new terminal
- Or run `hash -r` (bash) / `rehash` (zsh) to refresh the cache

## What does NOT transfer from Windows

- Windows Developer Mode toggle (irrelevant on Mac/Linux - symlinks work by default)
- `mklink /H` hard link command (not needed)
- `%APPDATA%` / `%USERPROFILE%` env vars (use `$HOME`)
- Junctions (not a Mac/Linux concept - symlinks cover the same use case)
- PowerShell-specific cp1252 / em-dash / `$varName:` gotchas (bash has its own gotchas but different)

## What DOES transfer cleanly

- The four-tier context loading model
- Memory-first routing logic
- Hook stack design (which hooks, why, what they enforce)
- MEMORY.md as index + topic files on demand
- Skill description-matching pattern
- `disable-model-invocation: true` for opt-in `/skill-name` shortcuts
- The research brief and best practices
- The CLI tool list (just installed via brew instead of winget)
- The architectural rationale in `docs/architecture.md` and `docs/why-this-pattern.md`
