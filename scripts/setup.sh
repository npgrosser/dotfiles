#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ZSHRC="$HOME/.zshrc"
ZSHRC_DOTFILES="$HOME/.zshrc_dotfiles"
LOCAL_BIN="$HOME/.local/bin"
DOTFILES_SOURCE_LINE='[ -f "$HOME/.zshrc_dotfiles" ] && source "$HOME/.zshrc_dotfiles"'
TMUX_CONF="$HOME/.tmux.conf"
GITCONFIG_DOTFILES="$HOME/.gitconfig_dotfiles"
OS="$(uname -s)"
FORCE="${FORCE_REINSTALL:-0}"

# --- Helper functions ---

# Check if a tool needs (re)install. Returns 0 if install needed, logs skip otherwise.
_needs() {
  [ "$FORCE" = "1" ] && return 0
  if command -v "$1" >/dev/null 2>&1 || [ -x "$LOCAL_BIN/$1" ]; then
    echo "  ✔ $1 already installed, skipping"
    return 1
  fi
}

_latest_tag() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | grep -o '"tag_name": *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"'
}

_brew_install() {
  for pkg in "$@"; do
    if [ "$FORCE" = "1" ]; then
      echo "🍺 Reinstalling $pkg (brew)..."
      brew reinstall "$pkg" 2>/dev/null || brew install "$pkg"
    elif ! brew list "$pkg" &>/dev/null; then
      echo "🍺 Installing $pkg (brew)..."
      brew install "$pkg"
    fi
  done
}

# portable sed -i (macOS sed requires '' after -i)
_sed_i() {
  if [ "$OS" = "Darwin" ]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# --- macOS: ensure Homebrew is available ---

if [ "$OS" = "Darwin" ] && ! command -v brew >/dev/null 2>&1; then
  echo "🍺 Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
fi

# --- 0. Ensure zsh and Oh My Zsh are available ---

if ! command -v zsh >/dev/null 2>&1; then
  echo "🐚 Installing zsh..."
  if [ "$OS" = "Darwin" ]; then
    brew install zsh
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y zsh
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y zsh
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm zsh
  else
    echo "⚠️  Could not install zsh automatically. Please install it manually."
    exit 1
  fi
fi

if [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
  echo "🔧 Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
fi

# --- 1. Install Starship prompt ---

if _needs starship; then
  echo "🚀 Installing Starship..."
  mkdir -p "$LOCAL_BIN"
  curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$LOCAL_BIN" > /dev/null
fi

echo "🚀 Installing Starship config..."
mkdir -p "$HOME/.config"
cp "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"

# --- 2. Install custom zsh config and helper commands ---

echo "📄 Installing ~/.zshrc_dotfiles..."
cp "$DOTFILES_DIR/config/zshrc_dotfiles" "$ZSHRC_DOTFILES"

echo "🔧 Installing dot..."
mkdir -p "$LOCAL_BIN"
cp "$DOTFILES_DIR/bin/dot" "$LOCAL_BIN/dot"
cp "$DOTFILES_DIR/bin/.dot.mk" "$LOCAL_BIN/.dot.mk"
chmod +x "$LOCAL_BIN/dot"

echo "🔧 Installing bwenv..."
cp "$DOTFILES_DIR/bin/bwenv" "$LOCAL_BIN/bwenv"
chmod +x "$LOCAL_BIN/bwenv"

if [ ! -f "$ZSHRC" ]; then
  touch "$ZSHRC"
fi

if ! grep -Fqx "$DOTFILES_SOURCE_LINE" "$ZSHRC"; then
  echo "🔗 Linking ~/.zshrc_dotfiles from ~/.zshrc..."
  # Remove old zshrc_custom source line if present
  if grep -q 'zshrc_custom' "$ZSHRC"; then
    _sed_i '/zshrc_custom/d' "$ZSHRC"
    _sed_i '/# Dotfiles custom config/d' "$ZSHRC"
  fi
  printf '\n# Dotfiles shared config\n%s\n' "$DOTFILES_SOURCE_LINE" >> "$ZSHRC"
fi

# fnm is initialized by ~/.zshrc_dotfiles. Remove legacy version-manager
# blocks from the host zshrc so Node is initialized exactly once.
if grep -q '^# fnm$' "$ZSHRC"; then
  echo "🧹 Removing legacy fnm block from ~/.zshrc..."
  _sed_i '/^# fnm$/,/^fi$/d' "$ZSHRC"
fi
if grep -q 'NVM_DIR' "$ZSHRC"; then
  echo "🧹 Removing legacy nvm initialization from ~/.zshrc..."
  _sed_i '/^[[:space:]]*export NVM_DIR=/d' "$ZSHRC"
  _sed_i '\|NVM_DIR/nvm\.sh|d' "$ZSHRC"
  _sed_i '\|NVM_DIR/bash_completion|d' "$ZSHRC"
fi

# --- 3. Install git config (via include, preserves user.name/email) ---

echo "📄 Installing ~/.gitconfig_dotfiles..."
cp "$DOTFILES_DIR/config/gitconfig" "$GITCONFIG_DOTFILES"

if ! grep -q 'path = ~/.gitconfig_dotfiles' "$HOME/.gitconfig" 2>/dev/null; then
  echo "🔗 Adding include to ~/.gitconfig..."
  printf '\n[include]\n\tpath = ~/.gitconfig_dotfiles\n' >> "$HOME/.gitconfig"
fi

# --- 4. Install platform-specific tools (eza, bat, rg, gh, etc.) ---

if [ "$OS" = "Darwin" ]; then
  _brew_install tmux eza bat ripgrep gh lazydocker jq yq
else
  # eza, bat, rg via pre-built Linux binaries
  _arch_musl() { uname -m; }

  if _needs eza; then
    echo "📦 Installing eza..."
    _tag="$(_latest_tag eza-community/eza)"
    _tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/eza-community/eza/releases/download/${_tag}/eza_$(_arch_musl)-unknown-linux-musl.tar.gz" \
      | tar -xz -C "$_tmp"
    mv "$_tmp/eza" "$LOCAL_BIN/eza"
    rm -rf "$_tmp"
  fi

  if _needs bat; then
    echo "📦 Installing bat..."
    _tag="$(_latest_tag sharkdp/bat)"
    _tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/sharkdp/bat/releases/download/${_tag}/bat-${_tag}-$(_arch_musl)-unknown-linux-musl.tar.gz" \
      | tar -xz -C "$_tmp"
    mv "$_tmp/bat-${_tag}-$(_arch_musl)-unknown-linux-musl/bat" "$LOCAL_BIN/bat"
    rm -rf "$_tmp"
  fi

  if _needs rg; then
    echo "📦 Installing ripgrep..."
    _tag="$(_latest_tag BurntSushi/ripgrep)"
    _ver="${_tag#v}"
    _tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${_tag}/ripgrep-${_ver}-$(_arch_musl)-unknown-linux-musl.tar.gz" \
      | tar -xz -C "$_tmp"
    mv "$_tmp/ripgrep-${_ver}-$(_arch_musl)-unknown-linux-musl/rg" "$LOCAL_BIN/rg"
    rm -rf "$_tmp"
  fi

  # gh via pre-built Linux binary
  if _needs gh; then
    echo "📦 Installing GitHub CLI..."
    _tag="$(_latest_tag cli/cli)"
    _ver="${_tag#v}"
    _arch="$(case "$(uname -m)" in x86_64) echo amd64 ;; aarch64) echo arm64 ;; *) uname -m ;; esac)"
    _tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/cli/cli/releases/download/${_tag}/gh_${_ver}_linux_${_arch}.tar.gz" \
      | tar -xz -C "$_tmp"
    mv "$_tmp/gh_${_ver}_linux_${_arch}/bin/gh" "$LOCAL_BIN/gh"
    rm -rf "$_tmp"
  fi

  # lazydocker
  if _needs lazydocker; then
    echo "📦 Installing lazydocker..."
    _tag="$(_latest_tag jesseduffield/lazydocker)"
    _ver="${_tag#v}"
    _arch="$(case "$(uname -m)" in x86_64) echo x86_64 ;; aarch64) echo arm64 ;; *) uname -m ;; esac)"
    _tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/jesseduffield/lazydocker/releases/download/${_tag}/lazydocker_${_ver}_Linux_${_arch}.tar.gz" \
      | tar -xz -C "$_tmp"
    mv "$_tmp/lazydocker" "$LOCAL_BIN/lazydocker"
    rm -rf "$_tmp"
  fi

  # jq
  if _needs jq; then
    echo "📦 Installing jq..."
    _arch="$(case "$(uname -m)" in x86_64) echo amd64 ;; aarch64) echo arm64 ;; *) uname -m ;; esac)"
    curl -fsSL -o "$LOCAL_BIN/jq" "https://github.com/jqlang/jq/releases/latest/download/jq-linux-${_arch}"
    chmod +x "$LOCAL_BIN/jq"
  fi

  # yq
  if _needs yq; then
    echo "📦 Installing yq..."
    _arch="$(case "$(uname -m)" in x86_64) echo amd64 ;; aarch64) echo arm64 ;; *) uname -m ;; esac)"
    curl -fsSL -o "$LOCAL_BIN/yq" "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${_arch}"
    chmod +x "$LOCAL_BIN/yq"
  fi
fi

echo "📄 Installing Ghostty config..."
if [ "$(uname)" = "Darwin" ]; then
  GHOSTTY_CONFIG_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
  GHOSTTY_PLATFORM_CONFIG="$DOTFILES_DIR/config/ghostty/config-darwin"
else
  GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
  GHOSTTY_PLATFORM_CONFIG="$DOTFILES_DIR/config/ghostty/config-linux"
fi
mkdir -p "$GHOSTTY_CONFIG_DIR"
cp "$DOTFILES_DIR/config/ghostty/config" "$GHOSTTY_CONFIG_DIR/config"
cp "$GHOSTTY_PLATFORM_CONFIG" "$GHOSTTY_CONFIG_DIR/config-platform"

echo "📄 Installing Neovim config..."
mkdir -p "$HOME/.config/nvim/lua/plugins"
cp "$DOTFILES_DIR/config/nvim/lua/plugins/colorscheme.lua" "$HOME/.config/nvim/lua/plugins/colorscheme.lua"
cp "$DOTFILES_DIR/config/nvim/lua/plugins/snacks.lua" "$HOME/.config/nvim/lua/plugins/snacks.lua"

echo "📄 Installing Zellij config..."
mkdir -p "$HOME/.config/zellij"
sed "s|__HOME__|$HOME|g" "$DOTFILES_DIR/config/zellij/config.kdl" > "$HOME/.config/zellij/config.kdl"
cp "$DOTFILES_DIR/config/zellij/copy.sh" "$HOME/.config/zellij/copy.sh"
chmod +x "$HOME/.config/zellij/copy.sh"

echo "📄 Installing Zed keymap..."
if [ "$(uname)" = "Darwin" ]; then
  ZED_CONFIG_DIR="$HOME/.config/zed"
else
  ZED_CONFIG_DIR="$HOME/.config/zed"
fi
mkdir -p "$ZED_CONFIG_DIR"
cp "$DOTFILES_DIR/config/zed/keymap.json" "$ZED_CONFIG_DIR/keymap.json"

echo "📄 Installing ~/.tmux.conf..."
cp "$DOTFILES_DIR/config/tmux.conf" "$TMUX_CONF"

echo "🤖 Configuring Claude Code settings..."
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CLAUDE_DEFAULTS="$DOTFILES_DIR/config/claude/settings.json"
mkdir -p "$HOME/.claude"
if [ ! -f "$CLAUDE_SETTINGS" ]; then
  cp "$CLAUDE_DEFAULTS" "$CLAUDE_SETTINGS"
else
  # Deep-merge: dotfiles defaults + existing settings (existing wins)
  jq -s '.[0] * .[1]' "$CLAUDE_DEFAULTS" "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" \
    && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
fi

mkdir -p "$HOME/.claude/plugins/claude-hud"
cp "$DOTFILES_DIR/config/claude/plugins/claude-hud/config.json" "$HOME/.claude/plugins/claude-hud/config.json"

# --- 5. Install VS Code extensions list ---

echo "💻 Installing VS Code extensions list..."
mkdir -p "$HOME/.config/dotfiles"
cp "$DOTFILES_DIR/config/vscode-extensions.txt" "$HOME/.config/dotfiles/vscode-extensions.txt"

# --- 6. Install cross-platform tools (Claude CLI, uv, fnm + Node.js) ---

if _needs claude; then
  echo "🤖 Installing Claude CLI..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

if _needs uv; then
  echo "📦 Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

FNM_INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
if [ "$OS" = "Darwin" ]; then
  _brew_install fnm
elif [ "$FORCE" = "1" ] \
  || { ! command -v fnm >/dev/null 2>&1 && [ ! -x "$FNM_INSTALL_DIR/fnm" ]; }; then
  echo "📦 Installing fnm..."
  _fnm_install_args=(--skip-shell)
  if [ "$FORCE" = "1" ]; then
    _fnm_install_args+=(--force-install)
  fi
  curl -fsSL https://fnm.vercel.app/install | bash -s -- "${_fnm_install_args[@]}"
else
  echo "  ✔ fnm already installed, skipping"
fi

if [ -x "$FNM_INSTALL_DIR/fnm" ]; then
  export PATH="$FNM_INSTALL_DIR:$PATH"
fi
if ! command -v fnm >/dev/null 2>&1; then
  echo "⚠️  fnm installation failed or fnm is not on PATH."
  exit 1
fi

eval "$(fnm env --shell bash)"
if [ "$FORCE" = "1" ] || ! _fnm_default="$(fnm default 2>/dev/null)"; then
  echo "📦 Installing the latest Node.js via fnm..."
  fnm install --latest --use
  _fnm_version="$(fnm current)"
  fnm default "${_fnm_version#v}"
else
  echo "  ✔ Node.js $_fnm_default already configured via fnm"
  fnm use --install-if-missing --silent-if-unchanged "$_fnm_default"
fi
unset FNM_INSTALL_DIR _fnm_default _fnm_install_args _fnm_version

# --- 7. Install zsh plugins ---

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  echo "🔌 Installing zsh-autosuggestions..."
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  echo "🔌 Installing zsh-syntax-highlighting..."
  git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [ ! -d "$HOME/.local/share/z" ]; then
  echo "📂 Installing z (rupa/z)..."
  mkdir -p "$HOME/.local/share"
  git clone --depth 1 https://github.com/rupa/z.git "$HOME/.local/share/z"
fi

if [ ! -d "$HOME/.fzf" ]; then
  echo "🔍 Installing fzf..."
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all --no-update-rc
fi

# --- 8. Configure .zshrc ---

_desired_plugins="git zsh-autosuggestions zsh-syntax-highlighting sudo"

if grep -q 'plugins=(' "$ZSHRC"; then
  # Replace existing plugins line with desired set
  if ! grep -q "zsh-autosuggestions" "$ZSHRC"; then
    echo "⚙️  Configuring zsh plugins..."
    _sed_i "s/plugins=([^)]*)/plugins=($_desired_plugins)/" "$ZSHRC"
  fi
else
  # No plugins line at all — add one before the oh-my-zsh source line, or at the end
  echo "⚙️  Adding zsh plugins..."
  if grep -q 'oh-my-zsh.sh' "$ZSHRC"; then
    _sed_i "/oh-my-zsh.sh/i\\
plugins=($_desired_plugins)" "$ZSHRC"
  else
    printf '\nplugins=(%s)\n' "$_desired_plugins" >> "$ZSHRC"
  fi
fi

# Ensure oh-my-zsh is sourced (may be missing if --keep-zshrc kept a pre-existing .zshrc)
if ! grep -q 'oh-my-zsh.sh' "$ZSHRC"; then
  echo "🔗 Adding oh-my-zsh source to .zshrc..."
  # Insert after plugins line so plugins are set before oh-my-zsh loads them
  if grep -q 'plugins=(' "$ZSHRC"; then
    _sed_i "/plugins=(/a\\
export ZSH=\"\$HOME/.oh-my-zsh\"\\
source \"\$ZSH/oh-my-zsh.sh\"" "$ZSHRC"
  else
    printf '\nexport ZSH="$HOME/.oh-my-zsh"\nsource "$ZSH/oh-my-zsh.sh"\n' >> "$ZSHRC"
  fi
fi

if ! grep -q 'fzf.zsh' "$ZSHRC"; then
  echo "🔗 Adding fzf to .zshrc..."
  printf '\n# fzf key bindings and completion\n[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh\n' >> "$ZSHRC"
fi

if ! grep -q 'starship init zsh' "$ZSHRC"; then
  echo "🔗 Adding Starship init to .zshrc..."
  printf '\n# Starship prompt\neval "$(starship init zsh)"\n' >> "$ZSHRC"
fi

# --- 9. Warn if default shell is not zsh ---

LOGIN_SHELL="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7 || true)"
if [ -z "$LOGIN_SHELL" ]; then
  LOGIN_SHELL="${SHELL:-}"
fi

if [[ "$LOGIN_SHELL" != */zsh ]]; then
  echo ""
  echo "⚠️  Warning: default login shell is not zsh (${LOGIN_SHELL:-unknown})."
  echo "   Dotfiles are configured for zsh."
fi

echo ""
# Show version info (commit hash + date)
_dotfiles_repo="${DOTFILES_REPO:-npgrosser/dotfiles}"
_dotfiles_ref="${DOTFILES_REF:-main}"
_version_info=""
if [ -d "$DOTFILES_DIR/.git" ]; then
  # Local install: read from git directly
  _version_info="$(git -C "$DOTFILES_DIR" log -1 --format='%h (%ci)' 2>/dev/null || true)"
elif command -v curl >/dev/null 2>&1; then
  # Remote install: fetch from GitHub API
  _commit_json="$(curl -fsSL "https://api.github.com/repos/${_dotfiles_repo}/commits/${_dotfiles_ref}" 2>/dev/null || true)"
  if [ -n "$_commit_json" ]; then
    _sha="$(echo "$_commit_json" | jq -r '.sha[:7]' 2>/dev/null || true)"
    _date="$(echo "$_commit_json" | jq -r '.commit.committer.date[:19] | sub("T"; " ")' 2>/dev/null || true)"
    [ -n "$_sha" ] && [ -n "$_date" ] && _version_info="$_sha ($_date)"
  fi
fi

echo "✅ Dotfiles installed!"
if [ -n "$_version_info" ]; then
  echo "   Version: $_version_info"
fi
if [ -n "${DOT_AUTO_RELOAD:-}" ]; then
  echo "   Shell will reload automatically."
else
  echo "   Run 'dot reload' or restart your shell to apply changes."
fi
