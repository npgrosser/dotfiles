#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ZSHRC="$HOME/.zshrc"
ZSHRC_CUSTOM="$HOME/.zshrc_custom"
LOCAL_BIN="$HOME/.local/bin"
CUSTOM_SOURCE_LINE='[ -f "$HOME/.zshrc_custom" ] && source "$HOME/.zshrc_custom"'
TMUX_CONF="$HOME/.tmux.conf"

# 1. Install Starship prompt
if ! command -v starship >/dev/null 2>&1; then
  echo "==> Installing Starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes > /dev/null
fi

# 2. Apply Starship preset
echo "==> Applying Starship tokyo-night preset..."
mkdir -p "$HOME/.config"
starship preset tokyo-night -o "$HOME/.config/starship.toml"

# 3. Install custom zsh config and helper commands
echo "==> Installing ~/.zshrc_custom..."
cp "$DOTFILES_DIR/config/zshrc_custom" "$ZSHRC_CUSTOM"

echo "==> Installing dotadd helper..."
mkdir -p "$LOCAL_BIN"
cp "$DOTFILES_DIR/bin/dotadd" "$LOCAL_BIN/dotadd"
chmod +x "$LOCAL_BIN/dotadd"

if [ ! -f "$ZSHRC" ]; then
  touch "$ZSHRC"
fi

if ! grep -Fqx "$CUSTOM_SOURCE_LINE" "$ZSHRC"; then
  echo "==> Linking ~/.zshrc_custom from ~/.zshrc..."
  printf '\n# Dotfiles custom config\n%s\n' "$CUSTOM_SOURCE_LINE" >> "$ZSHRC"
fi

# 4. Install tmux config
echo "==> Installing ~/.tmux.conf..."
cp "$DOTFILES_DIR/config/tmux.conf" "$TMUX_CONF"

# 5. Install zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  echo "==> Installing zsh-autosuggestions..."
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# 6. Configure .zshrc
if grep -q 'plugins=(git)' "$ZSHRC"; then
  echo "==> Configuring zsh plugins..."
  sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions sudo)/' "$ZSHRC"
fi

if ! grep -q 'starship init zsh' "$ZSHRC"; then
  echo "==> Adding Starship init to .zshrc..."
  printf '\n# Starship prompt\neval "$(starship init zsh)"\n' >> "$ZSHRC"
fi

# 6. Warn if default shell is not zsh (no automatic chsh)
LOGIN_SHELL="$(getent passwd "$(id -un)" | cut -d: -f7 || true)"
if [ -z "$LOGIN_SHELL" ]; then
  LOGIN_SHELL="${SHELL:-}"
fi

if [[ "$LOGIN_SHELL" != */zsh ]]; then
  echo ""
  echo "==> Warning: default login shell is not zsh (${LOGIN_SHELL:-unknown})."
  echo "    Dotfiles are configured for zsh."
fi

echo ""
echo "==> Dotfiles installed!"
echo "    Restart your shell or run: exec zsh"
echo "    Then run: dotadd list"
