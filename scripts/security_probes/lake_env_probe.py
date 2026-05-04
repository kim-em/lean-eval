#!/usr/bin/env python3
"""
Confirm that `lake env <cmd>` does NOT elaborate any project Lean
source as a side effect.

The trust model in `scripts/evaluate_submission.py:_prime_workspace`
and `generated/*/WorkspaceTest.lean` depends on this: the only place
user-controlled `Submission.lean` should get elaborated is comparator's
sandboxed `safeLakeBuild Solution`. If `lake env` ever started building
project libraries, an attacker's `Submission.lean` would run outside
landrun before comparator even started — RCE on the runner.

This is a one-shot diagnostic, not a CI assertion. SECURITY.md cites
its outcome.

How it works:
  1. Build a synthetic workspace whose `Submission.lean` has top-level
     `initialize` and `#eval` blocks that print marker strings.
  2. Run `lake env -- true` (no inner build target). Assert no markers
     in stdout.
  3. Run `lake env -- lake env -- true` (nested) — same.
  4. Run `lake env -- printenv | grep -c PATH` — sanity check that
     `lake env` did set PATH (i.e. it really ran, just didn't elaborate).
"""

from __future__ import annotations

import argparse
import pathlib
import shutil
import subprocess
import sys
import tempfile

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
TOOLCHAIN = (REPO_ROOT / "lean-toolchain").read_text(encoding="utf-8").strip()


SUBMISSION_LEAN = r"""
import Lean

initialize do
  IO.println "PWNED-AT-LOAD-INIT"

#eval IO.println "PWNED-AT-LOAD-EVAL"

namespace Submission
def marker : String := "PWNED-AT-LOAD-DEF"
end Submission
"""

LAKEFILE_TOML = """\
name = "lake_env_probe"

[[lean_lib]]
name = "Submission"
"""


class ProbeError(Exception):
    pass


def _check_tools(require: bool) -> list[str]:
    missing = [t for t in ("lake", "lean") if shutil.which(t) is None]
    if missing and require:
        raise ProbeError(f"Missing tools: {', '.join(missing)}")
    return missing


def _write_workspace(workspace: pathlib.Path) -> None:
    (workspace / "lakefile.toml").write_text(LAKEFILE_TOML, encoding="utf-8")
    (workspace / "lean-toolchain").write_text(TOOLCHAIN + "\n", encoding="utf-8")
    (workspace / "Submission.lean").write_text(SUBMISSION_LEAN, encoding="utf-8")


def _run(cmd: list[str], cwd: pathlib.Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd, cwd=cwd, capture_output=True, text=True, check=False, timeout=120
    )


def _has_pwned(text: str) -> list[str]:
    return [line for line in text.splitlines() if "PWNED-AT-LOAD" in line]


def run_probe(*, require_tools: bool = False) -> int:
    missing = _check_tools(require=require_tools)
    if missing and not require_tools:
        print(
            f"lake_env_probe: skipped (missing tools: {', '.join(missing)})",
            file=sys.stderr,
        )
        return 0
    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix="lake_env_probe_") as tmp:
        workspace = pathlib.Path(tmp) / "ws"
        workspace.mkdir(parents=True)
        _write_workspace(workspace)

        # 1. lake env -- true  (must not elaborate Submission)
        r = _run(["lake", "env", "true"], workspace)
        leaks = _has_pwned(r.stdout) + _has_pwned(r.stderr)
        if leaks:
            failures.append(
                "`lake env -- true` elaborated Submission.lean (PWNED markers found):\n  "
                + "\n  ".join(leaks)
            )
        else:
            print("lake_env_probe: `lake env -- true` did not elaborate Submission. PASS")

        # 2. lake env -- lake env -- true  (nested)
        r = _run(["lake", "env", "lake", "env", "true"], workspace)
        leaks = _has_pwned(r.stdout) + _has_pwned(r.stderr)
        if leaks:
            failures.append(
                "`lake env -- lake env -- true` elaborated Submission.lean (PWNED found):\n  "
                + "\n  ".join(leaks)
            )
        else:
            print(
                "lake_env_probe: nested `lake env -- lake env -- true` did not elaborate. PASS"
            )

        # 3. Sanity: lake env actually set up env.
        r = _run(["lake", "env", "printenv", "PATH"], workspace)
        if r.returncode != 0 or not r.stdout.strip():
            failures.append(
                "`lake env -- printenv PATH` produced no output; lake env may not be functioning at all"
            )
        else:
            print("lake_env_probe: `lake env -- printenv PATH` returns a PATH. PASS (sanity)")

    if failures:
        print("lake_env_probe: FAIL", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 1
    print("lake_env_probe: PASS — `lake env` does not elaborate project Lean.")
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-tools", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        return run_probe(require_tools=args.require_tools)
    except ProbeError as exc:
        print(f"lake_env_probe: error\n  {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
