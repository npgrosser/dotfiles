#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ZSHRC="$HOME/.zshrc"
ZSHRC_CUSTOM="$HOME/.zshrc_custom"
LOCAL_BIN="$HOME/.local/bin"
CUSTOM_SOURCE_LINE='[ -f "$HOME/.zshrc_custom" ] && source "$HOME/.zshrc_custom"'
TMUX_CONF="$HOME/.tmux.conf"
GITCONFIG_DOTFILES="$HOME/.gitconfig_dotfiles"
GITCONFIG_INCLUDE='[include]\n\tpath = ~/.gitconfig_dotfiles'

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

# 4. Install git config (via include, preserves user.name/email)
echo "==> Installing ~/.gitconfig_dotfiles..."
cp "$DOTFILES_DIR/config/gitconfig" "$GITCONFIG_DOTFILES"

if ! grep -q 'path = ~/.gitconfig_dotfiles' "$HOME/.gitconfig" 2>/dev/null; then
  echo "==> Adding include to ~/.gitconfig..."
  printf '\n[include]\n\tpath = ~/.gitconfig_dotfiles\n' >> "$HOME/.gitconfig"
fi

# 5. Install tmux config
echo "==> Installing ~/.tmux.conf..."
cp "$DOTFILES_DIR/config/tmux.conf" "$TMUX_CONF"

# 4b. Install shell tools (eza, bat, rg)
_latest_tag() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | grep -o '"tag_name": *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"'
}
_arch_musl() { uname -m; }

if ! command -v eza >/dev/null 2>&1 && [ ! -x "$LOCAL_BIN/eza" ]; then
  echo "==> Installing eza..."
  _tag="$(_latest_tag eza-community/eza)"
  _tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/eza-community/eza/releases/download/${_tag}/eza_$(_arch_musl)-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$_tmp"
  mv "$_tmp/eza" "$LOCAL_BIN/eza"
  rm -rf "$_tmp"
fi

if ! command -v bat >/dev/null 2>&1 && [ ! -x "$LOCAL_BIN/bat" ]; then
  echo "==> Installing bat..."
  _tag="$(_latest_tag sharkdp/bat)"
  _tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/sharkdp/bat/releases/download/${_tag}/bat-${_tag}-$(_arch_musl)-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$_tmp"
  mv "$_tmp/bat-${_tag}-$(_arch_musl)-unknown-linux-musl/bat" "$LOCAL_BIN/bat"
  rm -rf "$_tmp"
fi

if ! command -v rg >/dev/null 2>&1 && [ ! -x "$LOCAL_BIN/rg" ]; then
  echo "==> Installing ripgrep..."
  _tag="$(_latest_tag BurntSushi/ripgrep)"
  _ver="${_tag#v}"
  _tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${_tag}/ripgrep-${_ver}-$(_arch_musl)-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$_tmp"
  mv "$_tmp/ripgrep-${_ver}-$(_arch_musl)-unknown-linux-musl/rg" "$LOCAL_BIN/rg"
  rm -rf "$_tmp"
fi

# 5. Install zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  echo "==> Installing zsh-autosuggestions..."
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  echo "==> Installing zsh-syntax-highlighting..."
  git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# 5b. Install fzf
if [ ! -d "$HOME/.fzf" ]; then
  echo "==> Installing fzf..."
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all --no-update-rc
fi

# 6. Configure .zshrc
if grep -q 'plugins=(git)' "$ZSHRC"; then
  echo "==> Configuring zsh plugins..."
  sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting sudo)/' "$ZSHRC"
fi

# Idempotent: add zsh-syntax-highlighting if missing (handles re-runs after old setup)
if ! grep -q 'zsh-syntax-highlighting' "$ZSHRC"; then
  sed -i 's/plugins=(\([^)]*\))/plugins=(\1 zsh-syntax-highlighting)/' "$ZSHRC"
fi

if ! grep -q 'fzf.zsh' "$ZSHRC"; then
  echo "==> Adding fzf to .zshrc..."
  printf '\n# fzf key bindings and completion\n[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh\n' >> "$ZSHRC"
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
