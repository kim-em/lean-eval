#!/Users/kim/.local/share/uv/tools/aristotlelib/bin/python
"""Manage the Aristotle negation queue.

One iteration:
  1. Poll every entry in `aristotle-negations/state.json` whose status is
     `submitted`. If Aristotle reports COMPLETE, download and classify the
     result as `broken` / `verified` / `inconclusive`.
  2. Submit up to (5 - in-flight) entries currently `ready_to_submit`.
  3. Print a summary; surface any newly-`broken` problems with a loud banner
     so the loop driver (Claude or a human) can act on it.

Drive with `/loop 10m scripts/aristotle/poll_queue.py` once seeded.

state.json schema (per problem id):

  {
    "status": "ready_to_submit" | "submitted" | "complete"
            | "broken" | "verified" | "inconclusive"
            | "skipped" | "error",
    "prompt": str,                       # only meaningful while ready_to_submit
    "project_id": str | None,
    "submitted_at": ISO-8601 str | None,
    "completed_at": ISO-8601 str | None,
    "skip_reason": str | None,
    "notes": str | None,
    "notified": bool,                    # true once Claude/human has seen this break
  }
"""

from __future__ import annotations

import asyncio
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

import aristotlelib

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
NEG_ROOT = REPO_ROOT / "aristotle-negations"
STATE_PATH = NEG_ROOT / "state.json"
RESULTS_ROOT = NEG_ROOT / "results"
FINDINGS_ROOT = NEG_ROOT / "findings"
SUMMARY_PATH = FINDINGS_ROOT / "SUMMARY.md"

MAX_INFLIGHT = 5

# A distinctive substring Aristotle leaves in the output when it determined
# the submitted statement (here: a *negation*) is itself false. For us that
# means "Aristotle could not falsify the original" — boring but reassuring.
ARISTOTLE_FALSE_MARKER = "Aristotle found this block to be false"


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_state() -> dict:
    if not STATE_PATH.exists():
        return {}
    return json.loads(STATE_PATH.read_text())


def save_state(state: dict) -> None:
    tmp = STATE_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(state, indent=2, sort_keys=True))
    tmp.replace(STATE_PATH)


def workspace_for(problem_id: str) -> Path:
    return NEG_ROOT / problem_id


def submit(problem_id: str, prompt: str) -> str:
    """Run `aristotle submit` and return the new project_id.

    The CLI prints `Project created: <id>` on success. We capture stdout and
    pull the id back out of it.
    """
    proj_dir = workspace_for(problem_id)
    if not proj_dir.is_dir():
        raise RuntimeError(f"workspace missing: {proj_dir}")
    cmd = [
        "aristotle", "submit", prompt,
        "--project-dir", str(proj_dir),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    out = result.stdout + result.stderr
    m = re.search(r"Project created:\s*(\S+)", out)
    if not m:
        raise RuntimeError(f"could not parse project id from aristotle output:\n{out}")
    return m.group(1)


async def fetch_project(project_id: str):
    return await aristotlelib.Project.from_id(project_id)


def aristotle_status_to_label(status) -> str:
    """Map aristotlelib.ProjectStatus -> our short string."""
    return getattr(status, "value", str(status)).upper()


def extract_result_archive(result_path: Path) -> Path:
    """`aristotle result` writes a single tar.gz archive at --destination.
    Extract it next to the archive (sibling dir) and return that dir."""
    if result_path.is_dir():
        return result_path
    extract_dir = result_path.parent / (result_path.name + "_extracted")
    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    extract_dir.mkdir(parents=True)
    with tarfile.open(result_path, "r:gz") as tf:
        tf.extractall(extract_dir)
    return extract_dir


def classify_result_dir(result_dir: Path) -> str:
    """Return one of 'broken', 'verified', 'inconclusive'.

    Strategy: read every .lean file Aristotle handed back; if any of them
    contain ARISTOTLE_FALSE_MARKER, the *negation* was determined false and
    we conclude `verified` (the original is true). Otherwise, if any file
    contains a real (non-`sorry`/`admit`) proof body for a `*_negation`
    theorem, the negation was proved -- the original is `broken`. Otherwise
    we have no useful signal -> `inconclusive`.
    """
    result_dir = extract_result_archive(result_dir)
    lean_files = list(result_dir.rglob("*.lean"))
    saw_proof = False
    for lf in lean_files:
        try:
            text = lf.read_text()
        except Exception:
            continue
        if ARISTOTLE_FALSE_MARKER in text:
            return "verified"
        # Look for a *_negation theorem with a non-sorry body. We're lenient
        # here: anything that isn't just `by sorry` / `by admit` counts as a
        # proof. Aristotle wraps proofs in `by ...` blocks, sometimes long.
        # Locate each `theorem foo_negation ... :=` and grab everything
        # after the `:=` up to the next top-level decl or end-of-file.
        for m in re.finditer(r"theorem\s+(\w+_negation)\b", text):
            after = text[m.end():]
            # The theorem-body delimiter is the LAST top-level `:= ...` before
            # the next top-level decl or EOF (signature can contain nested
            # `haveI : ... := ...`, hence not the first `:=`).
            end_match = re.search(r"\n(?:theorem|lemma|def|instance|example|namespace|end\b|/-)", after)
            scope = after[: end_match.start()] if end_match else after
            seps = list(re.finditer(r":=\s*", scope))
            if not seps:
                continue
            body_start = seps[-1].end()
            body = scope[body_start:].strip()
            # Strip Lean line comments (`-- ...`) and block comments (`/- ... -/`),
            # plus the leading `by`, so we can reliably tell whether what's left
            # is just `sorry`/`admit` or a genuine proof.
            cleaned = re.sub(r"/-[\s\S]*?-/", "", body)
            cleaned = re.sub(r"--[^\n]*", "", cleaned)
            cleaned = re.sub(r"^\s*by\b", "", cleaned).strip()
            if cleaned and not re.fullmatch(r"(sorry|admit)\s*", cleaned):
                saw_proof = True
                break
        if saw_proof:
            break
    return "broken" if saw_proof else "inconclusive"


async def poll_one(problem_id: str, entry: dict) -> dict:
    """Update `entry` in place by polling Aristotle. Return entry."""
    pid = entry.get("project_id")
    if not pid:
        return entry
    project = await fetch_project(pid)
    status = aristotle_status_to_label(project.status)
    # `COMPLETE` and `COMPLETE_WITH_ERRORS` are both terminal — Aristotle
    # publishes whatever progress it made and we can download + classify.
    terminal = {"COMPLETE", "COMPLETE_WITH_ERRORS"}
    if status not in terminal:
        # Still in flight; record the latest observation in `notes`.
        entry["notes"] = f"aristotle status: {status} ({getattr(project, 'percent_complete', '?')}%)"
        return entry
    # Complete. Download. `aristotle result` REQUIRES destination to not
    # already exist, so we make sure it doesn't (idempotent across reruns).
    result_dir = RESULTS_ROOT / problem_id
    if result_dir.exists():
        shutil.rmtree(result_dir)
    RESULTS_ROOT.mkdir(parents=True, exist_ok=True)
    cmd = ["aristotle", "result", pid, "--destination", str(result_dir)]
    subprocess.run(cmd, check=True, capture_output=True, text=True)
    label = classify_result_dir(result_dir)
    entry["status"] = label
    entry["completed_at"] = now_iso()
    entry["notes"] = f"classified as {label}"
    if label == "broken":
        write_finding(problem_id, result_dir, entry)
    return entry


def write_finding(problem_id: str, result_dir: Path, entry: dict) -> None:
    FINDINGS_ROOT.mkdir(parents=True, exist_ok=True)
    finding = FINDINGS_ROOT / f"{problem_id}.md"
    proof_excerpt = ""
    for lf in sorted(result_dir.rglob("*_aristotle.lean")) or sorted(result_dir.rglob("*.lean")):
        try:
            proof_excerpt = lf.read_text()
            break
        except Exception:
            continue
    finding.write_text(
        f"# Counterexample for `{problem_id}`\n\n"
        f"Aristotle proved the negation of this leaderboard problem. The original\n"
        f"statement is therefore broken.\n\n"
        f"- project_id: `{entry.get('project_id')}`\n"
        f"- submitted_at: {entry.get('submitted_at')}\n"
        f"- completed_at: {entry.get('completed_at')}\n\n"
        f"## Aristotle's proof of the negation\n\n```lean\n{proof_excerpt}\n```\n"
    )
    # Append a one-liner to SUMMARY.md.
    line = f"- [{problem_id}]({problem_id}.md) (project `{entry.get('project_id')}`, completed {entry.get('completed_at')})\n"
    if SUMMARY_PATH.exists():
        SUMMARY_PATH.write_text(SUMMARY_PATH.read_text() + line)
    else:
        SUMMARY_PATH.write_text("# Broken leaderboard problems\n\n" + line)


def submit_refill(state: dict) -> list[str]:
    """Submit up to (MAX_INFLIGHT - in-flight) ready problems. Return ids submitted."""
    inflight = sum(1 for e in state.values() if e.get("status") == "submitted")
    slots = MAX_INFLIGHT - inflight
    if slots <= 0:
        return []
    ready = sorted(
        ((pid, e) for pid, e in state.items() if e.get("status") == "ready_to_submit"),
        key=lambda kv: kv[1].get("queued_at", ""),
    )
    submitted = []
    for problem_id, entry in ready[:slots]:
        prompt = entry.get("prompt") or "Try to find a counterexample to this theorem; replace the sorry with a proof only if you do."
        try:
            project_id = submit(problem_id, prompt)
        except Exception as e:
            entry["status"] = "error"
            entry["notes"] = f"submit failed: {e}"
            continue
        entry["status"] = "submitted"
        entry["project_id"] = project_id
        entry["submitted_at"] = now_iso()
        submitted.append(problem_id)
    return submitted


async def main() -> int:
    if not STATE_PATH.exists():
        print(f"no state file at {STATE_PATH}; nothing to do")
        return 0
    state = load_state()

    # 1. Poll in-flight.
    polled = []
    for problem_id, entry in state.items():
        if entry.get("status") == "submitted":
            polled.append(problem_id)
            try:
                await poll_one(problem_id, entry)
            except Exception as e:
                entry["notes"] = f"poll failed: {e}"

    # 2. Refill.
    submitted = submit_refill(state)

    save_state(state)

    # 3. Summarise.
    counts = {}
    for e in state.values():
        counts[e.get("status", "?")] = counts.get(e.get("status", "?"), 0) + 1
    print("== Aristotle negation queue ==")
    for k in sorted(counts):
        print(f"  {k:18s} {counts[k]}")
    if submitted:
        print(f"\nsubmitted {len(submitted)}: {', '.join(submitted)}")
    if polled:
        print(f"polled    {len(polled)}: {', '.join(polled)}")

    # 4. Surface any new BROKEN.
    new_broken = [pid for pid, e in state.items()
                  if e.get("status") == "broken" and not e.get("notified")]
    if new_broken:
        banner = "!" * 78
        print(f"\n{banner}")
        for pid in new_broken:
            print(f"NEW BROKEN: {pid}  ->  aristotle-negations/findings/{pid}.md")
        print(f"{banner}\n")
        # Also fire a desktop notification if we can.
        try:
            subprocess.run([
                "osascript", "-e",
                f'display notification "{len(new_broken)} broken: {", ".join(new_broken)[:120]}" with title "Aristotle counterexample"'
            ], check=False)
        except FileNotFoundError:
            pass
        # Mark notified so we don't re-bang next iteration.
        for pid in new_broken:
            state[pid]["notified"] = True
        save_state(state)
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
