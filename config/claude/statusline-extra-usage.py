#!/usr/bin/env python3
"""The status line: claude-hud, plus what this session cost beyond the plan's included usage.

Claude Code hands the status line the session's cost at list prices (`cost.total_cost_usd`),
whether fast mode is on, and, on Pro and Max, how much of the 5-hour and the weekly limit is
used (`rate_limits`). Fast mode is always paid from usage credits, everything else once one of
those limits stands at 100 %. What the cost grows by meanwhile is summed per session and shows
in claude-hud's first line as `Extra $…`, `Extra $0` before. The sums live in
~/.cache/claude-statusline/extra-usage/.

Not seen: a model's own weekly limit (Fable's, say), which the status line is not told about.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

STATE_DIR = Path.home() / ".cache" / "claude-statusline" / "extra-usage"
KEEP_SECONDS = 30 * 24 * 3600
WINDOWS = ("five_hour", "seven_day")


def on_credits(payload: dict) -> bool:
    """Whether Claude Code bills usage credits now: in fast mode, or with a limit used up."""
    if payload.get("fast_mode") is True:
        return True
    limits = payload.get("rate_limits") or {}
    return any(((limits.get(window) or {}).get("used_percentage") or 0) >= 100 for window in WINDOWS)


def extra_usd(payload: dict) -> float | None:
    """The session's extra usage so far, with what its cost grew since the last run added if on credits."""
    session = payload.get("session_id")
    total = (payload.get("cost") or {}).get("total_cost_usd")
    if not isinstance(session, str) or not re.fullmatch(r"[\w-]+", session):
        return None
    if not isinstance(total, (int, float)):
        return None
    path = STATE_DIR / f"{session}.json"
    try:
        state = json.loads(path.read_text())
    except (OSError, ValueError):
        # A session seen for the first time: what it cost before is not counted.
        prune()
        state = {"total": total, "extra": 0.0}
    grown = total - state["total"]
    if grown > 0 and on_credits(payload):
        state["extra"] += grown
    state["total"] = total
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(state))
    tmp.replace(path)
    return state["extra"]


def prune() -> None:
    """Drops the sums of sessions untouched for a month."""
    cutoff = time.time() - KEEP_SECONDS
    for old in STATE_DIR.glob("*"):
        try:
            if old.stat().st_mtime < cutoff:
                old.unlink()
        except OSError:
            pass


def usd(amount: float) -> str:
    """claude-hud's money format, with a plain `$0` for nothing."""
    if amount <= 0:
        return "$0"
    if amount >= 1:
        return f"${amount:.2f}"
    if amount >= 0.1:
        return f"${amount:.3f}"
    return f"${amount:.4f}"


def claude_hud() -> list[str]:
    """The newest installed claude-hud, started as its setup does: bun on the sources, else node on the build."""
    config_dir = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")
    versions = [d for d in (config_dir / "plugins/cache/claude-hud/claude-hud").iterdir() if d.is_dir()]
    newest = max(versions, key=lambda d: tuple(int(p) if p.isdigit() else -1 for p in d.name.split(".")))
    runtime = shutil.which("bun") or shutil.which("node")
    if runtime is None:
        raise SystemExit(1)
    source = "src/index.ts" if Path(runtime).name == "bun" else "dist/index.js"
    return [runtime, str(newest / source)]


def main() -> int:
    raw = sys.stdin.buffer.read()
    command = claude_hud()
    env = None
    try:
        extra = extra_usd(json.loads(raw))
    except Exception:  # the HUD still shows, only without the label
        extra = None
    if extra is not None:
        command += ["--extra-cmd", f"printf '%s' 'Extra {usd(extra)}'"]
        env = {**os.environ, "CLAUDE_HUD_ALLOW_EXTRA_CMD": "1"}
    return subprocess.run(command, input=raw, env=env).returncode


if __name__ == "__main__":
    sys.exit(main())
