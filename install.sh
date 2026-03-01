#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-npgrosser/dotfiles}"
DOTFILES_REF="${DOTFILES_REF:-main}"
DOTFILES_CLEANUP="${DOTFILES_CLEANUP:-1}"

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
LOCAL_SETUP_SCRIPT="$SCRIPT_DIR/scripts/setup.sh"

run_local_setup() {
  bash "$LOCAL_SETUP_SCRIPT" "$@"
}

run_remote_setup() {
  echo "==> Bootstrapping dotfiles from GitHub ($DOTFILES_REPO@$DOTFILES_REF)..."

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required but not installed."
    exit 1
  fi
  if ! command -v tar >/dev/null 2>&1; then
    echo "tar is required but not installed."
    exit 1
  fi

  tmp_dir="$(mktemp -d)"
  archive_path="$tmp_dir/dotfiles.tar.gz"
  archive_url="https://codeload.github.com/${DOTFILES_REPO}/tar.gz/${DOTFILES_REF}"

  cleanup() {
    if [ "$DOTFILES_CLEANUP" = "1" ] && [ -d "$tmp_dir" ]; then
      rm -rf "$tmp_dir"
    fi
  }
  trap cleanup EXIT

  curl -fsSL "$archive_url" -o "$archive_path"
  tar -xzf "$archive_path" -C "$tmp_dir"

  extracted_dir="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  setup_script="$extracted_dir/scripts/setup.sh"

  if [ ! -f "$setup_script" ]; then
    echo "Could not find scripts/setup.sh in downloaded archive."
    exit 1
  fi

  bash "$setup_script" "$@"
}

if [ -f "$LOCAL_SETUP_SCRIPT" ]; then
  run_local_setup "$@"
else
  run_remote_setup "$@"
fi
