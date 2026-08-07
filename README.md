# Dotfiles

Personal dotfiles for zsh, prompt, terminal, and editor setup. Works on Linux and macOS.

## Install

### One-liner (direkt ohne Clone)
```bash
curl -fsSL https://raw.githubusercontent.com/npgrosser/dotfiles/refs/heads/main/install.sh | bash
```

`install.sh` is a bootstrapper. It downloads the repo archive and runs `scripts/setup.sh`.

## What gets installed

### Shell & Prompt
| Tool | Description | Install method |
|---|---|---|
| zsh | Shell | Package manager |
| Oh My Zsh | Zsh framework | Installer script |
| Starship | Cross-shell prompt | Installer script |
| zsh-autosuggestions | Fish-like autosuggestions | git clone |
| zsh-syntax-highlighting | Syntax highlighting for zsh | git clone |
| fzf | Fuzzy finder | git clone |

### CLI Tools
| Tool | Description | Linux | macOS |
|---|---|---|---|
| eza | Modern `ls` replacement | Binary download | brew |
| bat | Modern `cat` with syntax highlighting | Binary download | brew |
| ripgrep | Fast `grep` replacement | Binary download | brew |
| jq | JSON processor | Binary download | brew |
| yq | YAML processor | Binary download | brew |
| lazydocker | Docker TUI | Installer script | brew |

### Dev Tools (cross-platform)
| Tool | Description | Install method |
|---|---|---|
| Claude CLI | Anthropic Claude | Installer script |
| GitHub CLI | GitHub from the terminal | Binary download / brew |
| uv | Python package manager | Installer script |
| Node.js | JavaScript runtime (via fnm) | fnm |

### Config
- Starship `tokyo-night` preset
- `~/.zshrc_dotfiles` with aliases and PATH setup
- `~/.tmux.conf` with custom keybindings
- `~/.gitconfig_dotfiles` (included via `~/.gitconfig`)

On macOS, Homebrew is installed automatically if missing (required for CLI tools above).
On Linux, zsh is installed automatically via the system package manager (dnf, apt-get, or pacman) if missing.

## Structure

- `install.sh` → bootstrap entrypoint (local or remote)
- `scripts/setup.sh` → main idempotent setup logic
- `config/zshrc_dotfiles` → shared zsh config
- `bin/dot` → CLI helper (`dot add`, `dot update`, `dot install-vscode-ext`)

After install, restart your shell or run:

```bash
exec zsh
```

Available `dot` commands:

```bash
dot update                # pull latest dotfiles from GitHub and re-run setup
dot add list              # show available packages and install status
dot add rust              # install Rust toolchain
dot add gcloud            # install Google Cloud CLI
dot add bw                # install Bitwarden CLI
dot add cursor            # install Cursor CLI
dot install-vscode-ext    # install VS Code extensions from config
```

## bwenv – Bitwarden .env Sync

`bwenv` syncs `.env` files with Bitwarden as secure notes. Requires `bw` (Bitwarden CLI) and `jq`.

The project name is auto-detected from the git remote or directory name. Items are stored as `env/<project>` in Bitwarden.

```bash
bwenv push [project]    # push local .env to Bitwarden
bwenv pull [project]    # pull .env from Bitwarden to local
bwenv diff [project]    # show diff between local and Bitwarden
bwenv list              # list all stored .env items
```

## tmux Shortcuts

Custom keybindings (prefix = `Ctrl+b`):

| Shortcut | Action |
|---|---|
| `Alt+Shift+D` | Smart split: splits along longer axis (spiral layout) |
| `Ctrl+Shift+←/→/↑/↓` | Navigate panes |
| `Alt+Shift+←/→/↑/↓` | Resize pane (5 cols/rows) |
| `Prefix+v` | Enter scroll/copy mode |

In copy mode: arrow keys or PgUp/PgDn to scroll, `q` to exit.

## Troubleshooting

If `dot` is "command not found" in the current shell:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && exec zsh
```
