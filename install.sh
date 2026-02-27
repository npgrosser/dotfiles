#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────
#  Dotfiles – install.sh
#  Sets up the personal dev-shell environment.
#  Designed to be idempotent – safe to re-run.
#
#  Files are COPIED (not symlinked) so that things still
#  work when the dotfiles source dir is cleaned up
#  (e.g. DevPod clones into a temp directory).
#
#  Usage:
#    bash install.sh              # interactive
#    NONINTERACTIVE=1 bash install.sh   # CI / devcontainer
# ──────────────────────────────────────────────────────────
set -euo pipefail

_sudo() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
DOTFILES_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
ZSHRC="$HOME/.zshrc"
ZSHRC_CUSTOM="$HOME/.zshrc_custom"
LOCAL_BIN="$HOME/.local/bin"
INSTALL_CLAUDE_CMD="$LOCAL_BIN/install-claude"
CUSTOM_SOURCE_LINE='[ -f "$HOME/.zshrc_custom" ] && source "$HOME/.zshrc_custom"'

# ── 1. Install Starship prompt ───────────────────────────
if ! command -v starship &>/dev/null; then
  echo "==> Installing Starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes > /dev/null
fi

# ── 2. Apply Starship tokyo-night preset ─────────────────
echo "==> Applying Starship tokyo-night preset..."
mkdir -p ~/.config
starship preset tokyo-night -o ~/.config/starship.toml

# ── 3. Manage custom zsh config + helper commands ─────────
echo "==> Installing ~/.zshrc_custom..."
cat > "$ZSHRC_CUSTOM" <<'EOF'
# Dotfiles custom zsh config
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
EOF

echo "==> Installing install-claude helper..."
mkdir -p "$LOCAL_BIN"
cat > "$INSTALL_CLAUDE_CMD" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if command -v claude >/dev/null 2>&1; then
  echo "Claude CLI already installed: $(command -v claude)"
  exit 0
fi

curl -fsSL https://claude.ai/install.sh | bash

if command -v claude >/dev/null 2>&1; then
  echo "Claude CLI installed: $(command -v claude)"
elif [ -x "$HOME/.local/bin/claude" ]; then
  echo "Claude CLI installed at ~/.local/bin/claude (open a new shell or run: exec zsh)"
else
  echo "Warning: Claude CLI not detected after installer run."
fi
EOF
chmod +x "$INSTALL_CLAUDE_CMD"

if [ ! -f "$ZSHRC" ]; then
  touch "$ZSHRC"
fi

if ! grep -Fqx "$CUSTOM_SOURCE_LINE" "$ZSHRC"; then
  echo "==> Linking ~/.zshrc_custom from ~/.zshrc..."
  printf '\n# Dotfiles custom config\n%s\n' "$CUSTOM_SOURCE_LINE" >> "$ZSHRC"
fi

# ── 4. Zsh plugins (oh-my-zsh assumed pre-installed) ─────
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  echo "==> Installing zsh-autosuggestions..."
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# ── 5. Configure .zshrc ─────────────────────────────────
if [ -f "$ZSHRC" ]; then
  # Add plugins
  if grep -q 'plugins=(git)' "$ZSHRC"; then
    echo "==> Configuring zsh plugins..."
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions sudo)/' "$ZSHRC"
  fi

  # Add starship init directly (no external file needed)
  if ! grep -q 'starship init zsh' "$ZSHRC"; then
    echo "==> Adding Starship init to .zshrc..."
    printf '\n# Starship prompt\neval "$(starship init zsh)"\n' >> "$ZSHRC"
  fi
fi

echo ""
echo "==> Dotfiles installed!"
echo "    Restart your shell or run: exec zsh"
echo "    Then run: install-claude"
