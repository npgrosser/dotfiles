# .dot.mk — install recipes for dot add
.ONESHELL:
SHELL       := /bin/bash
.SHELLFLAGS := -euo pipefail -c

.PHONY: all rust gcloud cursor

all: rust gcloud cursor

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
