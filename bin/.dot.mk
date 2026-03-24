# .dot.mk — install recipes for dot add
.ONESHELL:
SHELL       := /bin/bash
.SHELLFLAGS := -euo pipefail -c

.PHONY: all rust gcloud cursor bw direnv

all: rust gcloud cursor bw direnv

rust:
	@if command -v rustc >/dev/null 2>&1 || [ -x "$$HOME/.cargo/bin/rustc" ]; then
		echo "rust: already installed"
	else
		echo "rust: installing..."
		curl -fsSL https://sh.rustup.rs | sh -s -- -y
	fi

gcloud:
	@if command -v gcloud >/dev/null 2>&1 || [ -d "$$HOME/google-cloud-sdk" ]; then
		echo "gcloud: already installed"
	else
		echo "gcloud: installing..."
		curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts
	fi

cursor:
	@if command -v cursor >/dev/null 2>&1 || [ -x "$$HOME/.local/bin/cursor" ]; then
		echo "cursor: already installed"
	else
		echo "cursor: installing..."
		curl -fsSL https://cursor.com/install | bash
	fi

bw:
	@if command -v bw >/dev/null 2>&1 || [ -x "$$HOME/.local/bin/bw" ]; then
		echo "bw: already installed"
	else
		echo "bw: installing..."
		tmpdir=$$(mktemp -d)
		curl -fsSL "https://vault.bitwarden.com/download/?app=cli&platform=linux" -o "$$tmpdir/bw.zip"
		unzip -o "$$tmpdir/bw.zip" -d "$$tmpdir"
		install -m 755 "$$tmpdir/bw" "$$HOME/.local/bin/bw"
		rm -rf "$$tmpdir"
		echo "bw: installed to ~/.local/bin/bw"
	fi

direnv:
	@if command -v direnv >/dev/null 2>&1; then
		echo "direnv: already installed"
	else
		echo "direnv: installing..."
		export bin_path="$$HOME/.local/bin"
		curl -sfL https://direnv.net/install.sh | bash
		echo "direnv: installed"
	fi
