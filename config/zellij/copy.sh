#!/bin/sh
if command -v wl-copy >/dev/null 2>&1; then
    wl-copy
elif command -v pbcopy >/dev/null 2>&1; then
    pbcopy
elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
fi
