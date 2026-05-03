#!/Users/kim/.local/share/uv/tools/aristotlelib/bin/python
"""Record a curated negation as ready_to_submit in state.json.

Usage: record_ready.py <problem_id> <prompt-text>

If <prompt-text> is "-", read prompt from stdin.
Idempotent: if the entry already exists, only update prompt + queued_at if it
is still in `ready_to_submit` state. Refuses to overwrite a submitted/complete
entry.
"""
import datetime as dt
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
STATE_PATH = REPO_ROOT / "aristotle-negations" / "state.json"


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    pid, prompt = sys.argv[1], sys.argv[2]
    if prompt == "-":
        prompt = sys.stdin.read()
    state = json.loads(STATE_PATH.read_text())
    existing = state.get(pid)
    if existing and existing.get("status") not in (None, "ready_to_submit", "skipped", "error"):
        print(f"refusing to overwrite {pid} (status={existing.get('status')})", file=sys.stderr)
        return 1
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    state[pid] = {
        "status": "ready_to_submit",
        "prompt": prompt,
        "queued_at": now,
        "project_id": None,
        "submitted_at": None,
        "completed_at": None,
        "skip_reason": None,
        "notes": None,
    }
    tmp = STATE_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(state, indent=2, sort_keys=True))
    tmp.replace(STATE_PATH)
    print(f"recorded {pid} as ready_to_submit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
