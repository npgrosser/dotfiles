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

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Install Starship prompt ───────────────────────────
if ! command -v starship &>/dev/null; then
  echo "==> Installing Starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes > /dev/null
fi

# ── 2. Copy starship.toml ────────────────────────────────
echo "==> Copying starship.toml..."
mkdir -p ~/.config
cp "$DOTFILES_DIR/starship.toml" ~/.config/starship.toml

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

  # Add starship init directly (no external file needed)
  if ! grep -q 'starship init zsh' ~/.zshrc; then
    echo "==> Adding Starship init to .zshrc..."
    printf '\n# Starship prompt\neval "$(starship init zsh)"\n' >> ~/.zshrc
  fi
fi

# ── 5. Set default shell to zsh ──────────────────────────
# Only run chsh in non-devcontainer environments.
# In devcontainers, the shell is already configured and chsh
# can interfere with the SSH tunnel (e.g. DevPod).
if [ -z "${REMOTE_CONTAINERS:-}${CODESPACES:-}${DEVPOD:-}" ]; then
  if [ "$(basename "$SHELL")" != "zsh" ] && command -v zsh &>/dev/null; then
    echo "==> Setting default shell to zsh..."
    _sudo chsh -s "$(command -v zsh)" "$(whoami)" 2>/dev/null || true
  fi
fi

echo ""
echo "==> Dotfiles installed!"
echo "    Restart your shell or run: exec zsh"
