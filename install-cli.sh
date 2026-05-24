#!/usr/bin/env bash
# Install the Tier 1 + Tier 2 CLI tools used by the Claude Code workflow (macOS / Linux).
#
# Idempotent. Safe to re-run.
#
# Tier 1 (always recommended): rg fd bat fzf jq xh zoxide
# Tier 2 (install-on-trigger): lazygit gron uv starship gh-dash
#
# Usage:
#   ./install-cli.sh                 # both tiers (default)
#   ./install-cli.sh --tier 1        # Tier 1 only
#   ./install-cli.sh --tier 2        # Tier 2 only

set -uo pipefail

TIER="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tier|-t) TIER="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--tier 1|2|all]"
            exit 0
            ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ "$TIER" != "1" && "$TIER" != "2" && "$TIER" != "all" && "$TIER" != "All" ]]; then
    echo "ERROR: --tier must be 1, 2, or all"
    exit 1
fi

# Lowercase for consistency
TIER=$(echo "$TIER" | tr '[:upper:]' '[:lower:]')

OS="$(uname -s)"
if [ "$OS" != "Darwin" ] && ! command -v apt-get >/dev/null 2>&1; then
    echo "WARNING: this script targets macOS (brew) and Debian-based Linux (apt)."
    echo "On other distros, install the tools manually using your package manager:"
    echo "  Tier 1: ripgrep fd bat fzf jq xh zoxide"
    echo "  Tier 2: lazygit gron uv starship gh-dash"
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "ERROR: Homebrew not installed. Run bootstrap.sh first, or install brew manually:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
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

# Tier 1 - foundation
if [[ "$TIER" = "1" || "$TIER" = "all" ]]; then
    echo "=== Tier 1 CLI foundation ==="
    ensure_brew ripgrep "ripgrep (rg)"
    ensure_brew fd
    ensure_brew bat
    ensure_brew fzf
    ensure_brew jq
    ensure_brew xh
    ensure_brew zoxide
    echo ""
fi

# Tier 2 - situational extras
if [[ "$TIER" = "2" || "$TIER" = "all" ]]; then
    echo "=== Tier 2 CLI extras ==="
    ensure_brew lazygit
    ensure_brew gron
    ensure_brew uv "uv (Python)"
    ensure_brew starship
    ensure_brew gh-dash
    echo ""
fi

# Shell profile additions - zoxide + starship + fzf history search
# Idempotent: only appends if the marker isn't already present.
PROFILE_FILE=""
if [ -n "${ZDOTDIR:-}" ] && [ -f "$ZDOTDIR/.zshrc" ]; then
    PROFILE_FILE="$ZDOTDIR/.zshrc"
elif [ -f "$HOME/.zshrc" ]; then
    PROFILE_FILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    PROFILE_FILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    PROFILE_FILE="$HOME/.bash_profile"
else
    # Default to zshrc on Mac, bashrc on Linux
    if [ "$OS" = "Darwin" ]; then
        PROFILE_FILE="$HOME/.zshrc"
    else
        PROFILE_FILE="$HOME/.bashrc"
    fi
    touch "$PROFILE_FILE"
fi

PROFILE_MARKER="# --- claude-setup-template CLI foundation ---"
PROFILE_END="# --- end claude-setup-template CLI foundation ---"

if grep -Fq "$PROFILE_MARKER" "$PROFILE_FILE" 2>/dev/null; then
    echo "[ok]      shell profile already has CLI foundation block ($PROFILE_FILE)"
else
    cat >> "$PROFILE_FILE" <<'EOF'

# --- claude-setup-template CLI foundation ---
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init "${SHELL##*/}")"
fi
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init "${SHELL##*/}")"
fi
if command -v fzf >/dev/null 2>&1; then
    # fzf reverse-history search bound to Ctrl-R
    if [[ "$SHELL" == *zsh* ]]; then
        source <(fzf --zsh) 2>/dev/null || true
    elif [[ "$SHELL" == *bash* ]]; then
        eval "$(fzf --bash)" 2>/dev/null || true
    fi
fi
# --- end claude-setup-template CLI foundation ---
EOF
    echo "[ok]      appended CLI foundation block to $PROFILE_FILE"
fi

echo ""
echo "=== CLI install complete ==="
echo "Open a new terminal for PATH + profile changes to take effect."
