#!/usr/bin/env python3
"""
Assert that comparator's landrun sandbox actually restricts writes from
inside `Submission.lean` elaboration.

This is the CI-gating probe required by SECURITY.md > "Validations done
at submission time" > sandbox-engaged. It exists because landrun is run
with `--best-effort`, which silently degrades to "no sandbox" when the
host kernel lacks landlock support or when a writable-path rule is
silently dropped — both of which would let an attacker's Submission
escape the sandbox without any visible failure.

How it works:

1. Build a synthetic comparator workspace under a tempdir, mirroring the
   `generated/<id>/` shape but with Lean stdlib only (no Mathlib, so the
   probe runs in seconds rather than minutes).
2. The synthetic `Submission.lean` contains an `initialize` block that
   attempts five writes and records the outcome of each to a results
   file inside `.lake/probe/results.txt` (the only path the sandbox is
   allowed to touch under our policy).
3. Run `lake env comparator config.json` exactly the way
   `generated/*/WorkspaceTest.lean` does. Comparator builds Solution
   (which imports Submission), elaborating the initialize block inside
   landrun.
4. Read the results file and the inside-ok marker. Assert: the four
   forbidden writes were denied AND the one allowed write succeeded.
   Anything else is a hard failure.

Failure modes this probe catches that a hand-rolled landrun call would
miss:
  - landrun's flag set drifts away from what comparator passes
  - landrun silently runs without sandbox on a kernel missing landlock
    (the `--best-effort` failure mode that motivated this probe)
  - the sandbox is over-broad on some path that's not /tmp
  - symlink resolution lets an inside-allowed path escape via a symlink
  - the executable-path rules let writes through that the rwx rules
    were supposed to block

False negatives a future maintainer should still beware of: if
comparator changes the order in which it builds Challenge vs Solution
and exports them, the initialize block may run in a different sandbox
configuration. Re-run this probe after any comparator pin bump.
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

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLCHAIN = (REPO_ROOT / "lean-toolchain").read_text(encoding="utf-8").strip()


SUBMISSION_LEAN = r"""
import Lean

open IO.FS in
private def tryWrite (label : String) (path : System.FilePath) : IO String := do
  try
    -- Attempt the write. If the sandbox is engaged the write must fail.
    IO.FS.writeFile path "x"
    return s!"ALLOWED {label} {path}"
  catch e =>
    return s!"DENIED  {label} {path} :: {e.toString.take 200}"

initialize do
  -- We are inside Submission's elaboration, which Comparator runs inside
  -- landrun with `--rwx <projectDir>/.lake`. Only writes that resolve
  -- (after symlink resolution) under `<projectDir>/.lake/...` should
  -- succeed. Everything else must be denied by landrun.
  let cwd ← IO.currentDir
  let resultsDir : System.FilePath := cwd / ".lake" / "probe"
  -- Create our results dir up front. This itself is a probe of the
  -- inside-ok policy: if this fails, the whole probe fails loudly
  -- because we have nowhere to write outcomes.
  IO.FS.createDirAll resultsDir
  let resultsPath : System.FilePath := resultsDir / "results.txt"
  let insideOkPath : System.FilePath := resultsDir / "inside-ok-probe"

  let attempts : List (String × System.FilePath) := [
    ("tmp",          ⟨"/tmp/sandbox-bypass-probe"⟩),
    ("home",         ⟨((← IO.getEnv "HOME").getD "/no-home") ++ "/sandbox-bypass-probe"⟩),
    ("dotdot",       cwd / ".." / "outside-workspace-probe"),
    ("symlink-out",  cwd / ".lake" / "escape" / "via-symlink-probe"),
    ("inside-ok",    insideOkPath),
  ]

  let mut lines : Array String := #[]
  for (label, path) in attempts do
    lines := lines.push (← tryWrite label path)
  IO.FS.writeFile resultsPath (String.intercalate "\n" lines.toList ++ "\n")
"""


CHALLENGE_LEAN = """\
-- Probe-internal: a trivially-true theorem so the sandbox-engaged probe
-- can run comparator end-to-end without depending on Mathlib.
theorem sandbox_engaged_probe_thm : True := True.intro
"""

SUBMISSION_THM_LEAN = """\
-- The Submission must export a theorem of the same statement so the
-- comparator's verifyMatch step succeeds and we exercise the full path
-- (build Solution -> export Solution -> verify). The interesting work
-- is in `Submission.lean`'s initialize block above; this file just
-- supplies the proof.
namespace Submission

theorem sandbox_engaged_probe_thm : True := True.intro

end Submission
"""

SOLUTION_LEAN = """\
import Submission
import Submission.Thm

theorem sandbox_engaged_probe_thm : True := Submission.sandbox_engaged_probe_thm
"""

WORKSPACE_TEST_LEAN = '''\
import Lean

def main : IO UInt32 := do
  let comparatorBin := (← IO.getEnv "COMPARATOR_BIN").getD "comparator"
  let child ← IO.Process.spawn {
    cmd := "lake"
    args := #["env", comparatorBin, "config.json"]
  }
  child.wait
'''

LAKEFILE_TOML = """\
name = "sandbox_engaged_probe"
defaultTargets = ["Challenge", "Solution", "Submission"]

[[lean_lib]]
name = "Challenge"

[[lean_lib]]
name = "Solution"

[[lean_lib]]
name = "Submission"

[[lean_exe]]
name = "workspace_test"
root = "WorkspaceTest"
"""

CONFIG_JSON = {
    "challenge_module": "Challenge",
    "solution_module": "Solution",
    "theorem_names": ["sandbox_engaged_probe_thm"],
    "permitted_axioms": ["propext", "Quot.sound", "Classical.choice"],
    "enable_nanoda": False,
}

EXPECTED_RESULTS = {
    "tmp": "DENIED",
    "home": "DENIED",
    "dotdot": "DENIED",
    "symlink-out": "DENIED",
    "inside-ok": "ALLOWED",
}


class ProbeError(Exception):
    """Raised when the probe detects a sandbox-policy violation."""


def _check_tools(require: bool) -> list[str]:
    missing: list[str] = []
    for tool in ("lake", "lean", "landrun", "comparator"):
        if shutil.which(tool) is None:
            missing.append(tool)
    if missing and require:
        raise ProbeError(
            f"Required tools not on PATH: {', '.join(missing)}. "
            "Install via the same procedure CI uses; see SECURITY.md > "
            "'Bumping pinned dependencies'."
        )
    return missing


def _write_workspace(workspace: pathlib.Path) -> None:
    (workspace / "lakefile.toml").write_text(LAKEFILE_TOML, encoding="utf-8")
    (workspace / "lean-toolchain").write_text(TOOLCHAIN + "\n", encoding="utf-8")
    (workspace / "Challenge.lean").write_text(CHALLENGE_LEAN, encoding="utf-8")
    (workspace / "Solution.lean").write_text(SOLUTION_LEAN, encoding="utf-8")
    (workspace / "Submission.lean").write_text(SUBMISSION_LEAN, encoding="utf-8")
    submission_dir = workspace / "Submission"
    submission_dir.mkdir(parents=True, exist_ok=True)
    (submission_dir / "Thm.lean").write_text(SUBMISSION_THM_LEAN, encoding="utf-8")
    (workspace / "WorkspaceTest.lean").write_text(WORKSPACE_TEST_LEAN, encoding="utf-8")
    (workspace / "config.json").write_text(
        json.dumps(CONFIG_JSON, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    # Set up the symlink-out vector before comparator runs. landrun must
    # deny writes through this symlink because the resolved path
    # (`/tmp/sandbox_engaged_probe_escape`) is not under any --rwx rule.
    lake_dir = workspace / ".lake"
    lake_dir.mkdir(parents=True, exist_ok=True)
    escape_target = pathlib.Path(tempfile.mkdtemp(prefix="sandbox_engaged_probe_escape_"))
    escape_link = lake_dir / "escape"
    if escape_link.exists() or escape_link.is_symlink():
        escape_link.unlink()
    escape_link.symlink_to(escape_target)


def _run_comparator(workspace: pathlib.Path) -> subprocess.CompletedProcess[str]:
    # Lake update + cache get are needed even for a stdlib-only project
    # to populate `.lake/build/` enough that comparator's safeLakeBuild
    # finds a working setup. With no Mathlib require we expect this to
    # be a no-op-ish but still required.
    for cmd in (["lake", "update"], ["lake", "exe", "cache", "get"]):
        # `cache get` only exists when mathlib is required; skip cleanly.
        result = subprocess.run(
            cmd, cwd=workspace, capture_output=True, text=True, check=False
        )
        if cmd[1] == "exe" and result.returncode != 0:
            # Expected: no `cache` exe in a stdlib-only workspace.
            continue
        if result.returncode != 0 and cmd[1] != "exe":
            raise ProbeError(
                f"`{' '.join(cmd)}` failed in {workspace}:\n{result.stderr.strip()}"
            )
    # Mirror what generated/<id>/WorkspaceTest.lean does: invoke comparator
    # with `lake env`. We use the binary directly (not via `lake test`)
    # so the probe doesn't depend on lake's testDriver behaviour.
    return subprocess.run(
        ["lake", "env", "comparator", "config.json"],
        cwd=workspace,
        capture_output=True,
        text=True,
        check=False,
    )


def _parse_results(workspace: pathlib.Path) -> dict[str, str]:
    results_path = workspace / ".lake" / "probe" / "results.txt"
    if not results_path.is_file():
        raise ProbeError(
            f"Results file not produced at {results_path}. The Submission's "
            "initialize block did not run, OR the inside-ok write failed "
            "(which would mean even the writable-path rule was dropped — a "
            "different sandbox failure)."
        )
    parsed: dict[str, str] = {}
    for line in results_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        # Expected shape: "DENIED  <label> <path> [:: <err>]"
        #              or "ALLOWED <label> <path>"
        head, _, _ = line.partition(" ")
        rest = line[len(head):].lstrip()
        label, _, _ = rest.partition(" ")
        parsed[label] = head.strip()
    return parsed


def _assert_results(workspace: pathlib.Path, parsed: dict[str, str]) -> list[str]:
    violations: list[str] = []
    for label, expected in EXPECTED_RESULTS.items():
        actual = parsed.get(label)
        if actual is None:
            violations.append(f"missing result for {label!r}")
            continue
        if actual != expected:
            violations.append(
                f"{label}: expected {expected}, got {actual}. "
                "If a forbidden write was ALLOWED, the sandbox is not "
                "engaged for that path. If the inside-ok write was DENIED, "
                "the writable-path rule is being dropped."
            )
    inside_ok_marker = workspace / ".lake" / "probe" / "inside-ok-probe"
    if not inside_ok_marker.is_file():
        violations.append(
            f"inside-ok marker missing at {inside_ok_marker}; even the "
            "allowed write did not land. Sandbox is broken in a different way."
        )
    return violations


def run_probe(*, require_tools: bool = False) -> int:
    missing = _check_tools(require=require_tools)
    if missing and not require_tools:
        print(
            f"sandbox_engaged_probe: skipped (missing tools: {', '.join(missing)}). "
            "Re-run with --require-tools (or in CI) to make this an error.",
            file=sys.stderr,
        )
        return 0
    with tempfile.TemporaryDirectory(prefix="sandbox_engaged_probe_") as tmp:
        workspace = pathlib.Path(tmp) / "ws"
        workspace.mkdir(parents=True)
        _write_workspace(workspace)
        result = _run_comparator(workspace)
        # Comparator's exit status is informative but secondary to the
        # results file. We surface it so a probe failure that's caused
        # by comparator itself crashing can be diagnosed.
        if result.returncode != 0:
            sys.stderr.write(
                "sandbox_engaged_probe: comparator exited "
                f"{result.returncode}. stdout/stderr follow:\n"
            )
            if result.stdout:
                sys.stderr.write(result.stdout)
            if result.stderr:
                sys.stderr.write(result.stderr)
        try:
            parsed = _parse_results(workspace)
        except ProbeError as exc:
            print(f"sandbox_engaged_probe: FAIL\n  {exc}", file=sys.stderr)
            return 1
        violations = _assert_results(workspace, parsed)
        if violations:
            print(
                "sandbox_engaged_probe: FAIL — sandbox is NOT engaged as expected.",
                file=sys.stderr,
            )
            for v in violations:
                print(f"  - {v}", file=sys.stderr)
            return 1
    print("sandbox_engaged_probe: PASS")
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--require-tools",
        action="store_true",
        help="Treat missing lake/lean/landrun/comparator as an error rather "
        "than a skip. CI must always pass this flag.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        return run_probe(require_tools=args.require_tools)
    except ProbeError as exc:
        print(f"sandbox_engaged_probe: error\n  {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
