#!/usr/bin/env bash
# Bootstrap a Claude Code dev environment from this template repo (macOS / Linux).
#
# Idempotent. Safe to re-run. Creates symlinks from ~/.claude/ into this
# repo's claude-config/, memory/, skills/, commands/ so Claude Code reads
# everything from git instead of from a one-off local install.
#
# Designed to be invoked by Claude Code in auto mode - all parameters are
# flags, no interactive prompts. See AGENTS.md for the autopilot flow.
#
# Usage:
#   ./bootstrap.sh --username "alice" --email "alice@example.com"
#   ./bootstrap.sh -u "alice" -e "alice@example.com" --skip-cli

set -uo pipefail

USERNAME=""
EMAIL=""
SKIP_CLI=false

usage() {
    cat <<EOF
Usage: $0 --username <github-username> --email <commit-email> [--skip-cli]

Required:
  --username, -u <name>    Your GitHub username (set as git user.name on this repo)
  --email, -e    <addr>    Your commit email (set as git user.email on this repo)

Optional:
  --skip-cli               Don't install Tier 1/2 CLI tools (rg, fd, etc.)
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --username|-u) USERNAME="${2:-}"; shift 2 ;;
        --email|-e)    EMAIL="${2:-}"; shift 2 ;;
        --skip-cli)    SKIP_CLI=true; shift ;;
        -h|--help)     usage ;;
        *) echo "Unknown argument: $1"; usage ;;
    esac
done

[ -z "$USERNAME" ] && { echo "ERROR: --username is required"; usage; }
[ -z "$EMAIL" ]    && { echo "ERROR: --email is required"; usage; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Claude Code dev environment bootstrap (macOS / Linux) ==="
echo "Identity: $USERNAME / $EMAIL"
echo ""

# Detect package manager - brew on Mac, apt on Linux (best-effort)
OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
    PKG_MGR="brew"
elif command -v apt-get >/dev/null 2>&1; then
    PKG_MGR="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
else
    echo "WARNING: unrecognized OS / package manager. Will try Homebrew."
    PKG_MGR="brew"
fi

# Install Homebrew on Mac if missing
if [ "$PKG_MGR" = "brew" ] && ! command -v brew >/dev/null 2>&1; then
    echo "[install] Homebrew (one-time, may prompt for sudo)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this script
    if [ -d /opt/homebrew/bin ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -d /usr/local/bin ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

ensure_brew() {
    local pkg="$1"
    local name="${2:-$1}"
    if brew list "$pkg" >/dev/null 2>&1; then
        echo "[ok]      $name already installed"
    else
        echo "[install] $name..."
        brew install "$pkg"
    fi
}

ensure_apt() {
    local pkg="$1"
    local name="${2:-$1}"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "[ok]      $name already installed"
    else
        echo "[install] $name..."
        sudo apt-get install -y "$pkg"
    fi
}

# Required tooling
if [ "$PKG_MGR" = "brew" ]; then
    ensure_brew git
    ensure_brew gh "GitHub CLI"
    ensure_brew node "Node.js"
elif [ "$PKG_MGR" = "apt" ]; then
    sudo apt-get update -q
    ensure_apt git
    # gh on apt requires a special repo - tell the user
    if ! command -v gh >/dev/null 2>&1; then
        echo "[manual]  GitHub CLI: see https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    fi
    ensure_apt nodejs "Node.js"
    ensure_apt npm
fi

# Install Claude Code via npm
if command -v claude >/dev/null 2>&1; then
    echo "[ok]      Claude Code already installed"
else
    echo "[install] Claude Code..."
    npm install -g @anthropic-ai/claude-code
fi

# Symlink helper
ensure_symlink() {
    local source="$1"
    local target="$2"
    local name="$3"

    # Ensure source directory exists (for dirs) or parent exists (for files)
    if [[ "$source" == */ ]] || [ -d "$source" ]; then
        mkdir -p "$source"
    else
        mkdir -p "$(dirname "$source")"
    fi
    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ]; then
        local current
        current=$(readlink "$target")
        if [ "$current" = "$source" ]; then
            echo "[ok]      $name symlink already exists"
            return
        else
            echo "[fix]     $name symlink points to wrong place, recreating"
            rm "$target"
        fi
    elif [ -e "$target" ]; then
        local backup="${target}.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$target" "$backup"
        echo "[backup]  existing $name -> $backup"
    fi

    ln -s "$source" "$target"
    echo "[ok]      created $name symlink"
}

# Memory symlink - path is derived from $HOME with slashes replaced by dashes
# Mirrors the Windows convention so memory loads automatically
CLAUDE_PROJECT_NAME=$(echo "$HOME" | sed 's|^/|-|; s|/|-|g')
MEMORY_LINK="$HOME/.claude/projects/${CLAUDE_PROJECT_NAME}/memory"
ensure_symlink "$REPO_ROOT/memory" "$MEMORY_LINK" "memory"

# Other symlinks (commands, skills, rules, hooks)
ensure_symlink "$REPO_ROOT/commands"            "$HOME/.claude/commands" "commands"
ensure_symlink "$REPO_ROOT/skills"              "$HOME/.claude/skills"   "skills"
ensure_symlink "$REPO_ROOT/claude-config/rules" "$HOME/.claude/rules"    "rules"
ensure_symlink "$REPO_ROOT/claude-config/hooks" "$HOME/.claude/hooks"    "hooks"

# User-scope CLAUDE.md - imports core rules from this repo
CLAUDE_MD_PATH="$HOME/.claude/CLAUDE.md"
CORE_RULES_PATH="$REPO_ROOT/memory/core-rules.md"
if [ ! -f "$CLAUDE_MD_PATH" ]; then
    mkdir -p "$(dirname "$CLAUDE_MD_PATH")"
    echo "@${CORE_RULES_PATH}" > "$CLAUDE_MD_PATH"
    echo "[ok]      created ~/.claude/CLAUDE.md -> core-rules.md"
else
    echo "[ok]      ~/.claude/CLAUDE.md already exists (not overwritten)"
fi

# Settings symlink - canonical settings.mac.json -> ~/.claude/settings.json
SETTINGS_SOURCE="$REPO_ROOT/claude-config/settings.mac.json"
SETTINGS_TARGET="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_SOURCE" ]; then
    if [ -L "$SETTINGS_TARGET" ]; then
        current=$(readlink "$SETTINGS_TARGET")
        if [ "$current" = "$SETTINGS_SOURCE" ]; then
            echo "[ok]      settings.json symlink already exists"
        else
            echo "[fix]     settings.json symlink points elsewhere, recreating"
            rm "$SETTINGS_TARGET"
            ln -s "$SETTINGS_SOURCE" "$SETTINGS_TARGET"
            echo "[ok]      created settings.json symlink"
        fi
    elif [ -e "$SETTINGS_TARGET" ]; then
        backup="${SETTINGS_TARGET}.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$SETTINGS_TARGET" "$backup"
        echo "[backup]  existing settings.json -> $backup"
        ln -s "$SETTINGS_SOURCE" "$SETTINGS_TARGET"
        echo "[ok]      created settings.json symlink"
    else
        ln -s "$SETTINGS_SOURCE" "$SETTINGS_TARGET"
        echo "[ok]      created settings.json symlink"
    fi
else
    echo "[warn]    claude-config/settings.mac.json missing - skipping settings link"
fi

# Make hook scripts executable
chmod +x "$REPO_ROOT/claude-config/hooks/"*.sh 2>/dev/null || true

# Per-repo git identity
CURRENT_EMAIL=$(git -C "$REPO_ROOT" config user.email 2>/dev/null || echo "")
if [ "$CURRENT_EMAIL" != "$EMAIL" ]; then
    git -C "$REPO_ROOT" config user.name "$USERNAME"
    git -C "$REPO_ROOT" config user.email "$EMAIL"
    echo "[ok]      set repo identity: $USERNAME / $EMAIL"
else
    echo "[ok]      repo identity already configured ($EMAIL)"
fi

# CLI tools
if [ "$SKIP_CLI" = false ]; then
    CLI_INSTALLER="$REPO_ROOT/install-cli.sh"
    if [ -f "$CLI_INSTALLER" ]; then
        echo ""
        echo "=== CLI tools ==="
        bash "$CLI_INSTALLER" --tier all
    else
        echo "[skip]    install-cli.sh not found - skipping CLI tools"
    fi
fi

# Verification
echo ""
echo "=== Verification ==="
failed=0
check() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        echo "[PASS]    $name"
    else
        echo "[FAIL]    $name"
        failed=$((failed + 1))
    fi
}

check "memory symlink"        "[ -L '$MEMORY_LINK' ] && [ -f '$MEMORY_LINK/MEMORY.md.template' -o -f '$MEMORY_LINK/MEMORY.md' ]"
check "commands symlink"      "[ -L '$HOME/.claude/commands' ]"
check "skills symlink"        "[ -L '$HOME/.claude/skills' ]"
check "rules symlink"         "[ -L '$HOME/.claude/rules' ]"
check "hooks symlink"         "[ -L '$HOME/.claude/hooks' ]"
check "settings symlink"      "[ -L '$SETTINGS_TARGET' ]"
check "~/.claude/CLAUDE.md"   "[ -f '$CLAUDE_MD_PATH' ]"
check "claude CLI installed"  "command -v claude"
check "git identity set"      "[ \"\$(git -C '$REPO_ROOT' config user.email)\" = '$EMAIL' ]"

echo ""
if [ $failed -eq 0 ]; then
    echo "=== Bootstrap complete - all checks passed ==="
else
    echo "=== Bootstrap complete with $failed failed check(s) ==="
fi

echo ""
echo "Next steps:"
if ! gh auth status 2>&1 | grep -q "Logged in"; then
    echo "  1. gh auth login                       (authenticate as $USERNAME)"
fi
echo "  2. Customize claude-config/hooks/*.template files - rename to .sh and fill in your rules"
echo "  3. Customize memory/MEMORY.md.template and memory/core-rules.md.template - rename to .md and fill in your project context"
echo "  4. Open a new terminal so PATH refreshes (npm/brew installs), then run: claude"
