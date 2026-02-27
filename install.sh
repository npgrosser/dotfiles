#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────
#  Dotfiles – install.sh
#  Sets up the personal dev-shell environment.
#  Designed to be idempotent – safe to re-run.
#
#  Usage:
#    bash install.sh              # interactive
#    NONINTERACTIVE=1 bash install.sh   # CI / devcontainer
# ──────────────────────────────────────────────────────────
set -euo pipefail

_sudo() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Install Starship prompt ───────────────────────────
if ! command -v starship &>/dev/null; then
  echo "==> Installing Starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
fi

# ── 2. Link starship.toml ────────────────────────────────
echo "==> Linking starship.toml..."
mkdir -p ~/.config
ln -sf "$DOTFILES_DIR/starship.toml" ~/.config/starship.toml

# ── 3. Zsh plugins (oh-my-zsh assumed pre-installed) ─────
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  echo "==> Installing zsh-autosuggestions..."
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# ── 4. Configure .zshrc ─────────────────────────────────
if [ -f ~/.zshrc ]; then
  # Add plugins
  if grep -q 'plugins=(git)' ~/.zshrc; then
    echo "==> Configuring zsh plugins..."
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions sudo)/' ~/.zshrc
  fi

  # Source .zshrc.local for personal config (starship, aliases, etc.)
  if ! grep -q '.zshrc.local' ~/.zshrc; then
    echo "==> Adding .zshrc.local source to .zshrc..."
    printf '\n# Personal dotfiles config\n[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local\n' >> ~/.zshrc
  fi
fi

# Link .zshrc.local
if [ -f "$DOTFILES_DIR/.zshrc.local" ]; then
  echo "==> Linking .zshrc.local..."
  ln -sf "$DOTFILES_DIR/.zshrc.local" ~/.zshrc.local
fi

# ── 5. Set default shell to zsh ──────────────────────────
if [ "$(basename "$SHELL")" != "zsh" ] && command -v zsh &>/dev/null; then
  echo "==> Setting default shell to zsh..."
  _sudo chsh -s "$(command -v zsh)" "$(whoami)" 2>/dev/null || true
fi

echo ""
echo "==> Dotfiles installed!"
echo "    Restart your shell or run: exec zsh"
