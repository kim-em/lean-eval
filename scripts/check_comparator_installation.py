#!/usr/bin/env python3
"""
Run a real comparator check against a tiny generated workspace.
"""

from __future__ import annotations

import os
import pathlib
import shutil
import subprocess
import sys
import tempfile


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent


def run(cmd: list[str], *, cwd: pathlib.Path) -> None:
    completed = subprocess.run(cmd, cwd=cwd, env=os.environ.copy(), text=True, check=False)
    if completed.returncode != 0:
        raise RuntimeError(f"Command failed with exit code {completed.returncode}: {' '.join(cmd)}")


def solve_two_plus_two(workspace: pathlib.Path) -> None:
    submission_path = workspace / "Submission.lean"
    content = submission_path.read_text(encoding="utf-8")
    if "  sorry\n" not in content:
        raise RuntimeError(f"Expected a placeholder proof in {submission_path}")
    submission_path.write_text(content.replace("  sorry\n", "  norm_num\n", 1), encoding="utf-8")


def main() -> int:
    source = REPO_ROOT / "generated" / "two_plus_two"
    if not source.is_dir():
        print(f"Missing generated workspace: {source}", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory() as tmpdir:
        workspace = pathlib.Path(tmpdir) / "two_plus_two"
        shutil.copytree(source, workspace)
        solve_two_plus_two(workspace)
        run(["lake", "update"], cwd=workspace)
        run(["lake", "exe", "cache", "get"], cwd=workspace)
        run(["lake", "test"], cwd=workspace)

    print("Comparator check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
