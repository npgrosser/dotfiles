# Dotfiles

Personal zsh shell and prompt setup.

## Install

### One-liner (direkt ohne Clone)
```bash
curl -fsSL https://raw.githubusercontent.com/npgrosser/dotfiles/refs/heads/main/install.sh | bash
```

`install.sh` is a bootstrapper. It downloads the repo archive and runs `scripts/setup.sh`.

## What it sets up

- Installs Starship prompt (if missing)
- Applies the `tokyo-night` Starship preset
- Installs `zsh-autosuggestions`
- Updates `~/.zshrc` plugins and Starship init
- Installs `~/.zshrc_custom` and sources it from `~/.zshrc`
- Ensures `~/.local/bin` is in `PATH` (via `~/.zshrc_custom`)
- Adds `~/.local/bin/install-claude` helper command

## Structure

- `install.sh` → bootstrap entrypoint (local or remote)
- `scripts/setup.sh` → main idempotent setup logic
- `config/zshrc_custom` → user zsh custom config
- `config/install-claude` → on-demand Claude installer command

After install, restart your shell or run:

```bash
exec zsh
```

Then install Claude on demand:

```bash
install-claude
```

## Optional: set zsh as default shell

If your login shell is not already `zsh`, you can set it with:

```bash
chsh -s "$(command -v zsh)"
```

Then log out and back in.

## Troubleshooting

If `install-claude` is "command not found" in the current shell:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && exec zsh
```
