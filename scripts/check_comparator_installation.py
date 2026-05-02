#!/usr/bin/env python3
"""
Run a real comparator check against a tiny generated workspace.

This script edits a `Submission.lean` with a maintainer-controlled proof
(`norm_num` for `2 + 2 = 4`) and then runs `lake update` + `lake exe
cache get` + `lake test` outside landrun. The `lake test` step invokes
WorkspaceTest -> comparator, and comparator's sandboxed `lake build`
inside landrun is what compiles the (maintainer-controlled) `Submission`.
The Submission content here is hardcoded by the maintainer, NEVER fed
from a submitter, so this script's pattern is safe even though it
superficially resembles `_prime_workspace` in scripts/evaluate_submission.py.

Do not generalize this script to accept submitter-supplied Submission
content without re-reading LANDRUN.md "What must not regress when this
is fixed".
"""

from __future__ import annotations

import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
MIN_LANDRUN_VERSION = (0, 1, 14)
LANDRUN_INSTALL_TARGET = "main"
REQUIRED_LANDRUN_FLAGS = (
    "--best-effort",
    "--ro",
    "--rw",
    "--rox",
    "--rwx",
    "--ldd",
    "--add-exec",
)


@dataclass(frozen=True)
class LandrunInspection:
    path: str
    help_text: str
    version_text: str | None
    version: tuple[int, int, int] | None


def format_version(version: tuple[int, int, int]) -> str:
    return f"v{version[0]}.{version[1]}.{version[2]}"


def parse_semver(text: str) -> tuple[int, int, int] | None:
    match = re.search(r"\bv?(\d+)\.(\d+)\.(\d+)\b", text)
    if match is None:
        return None
    return tuple(int(part) for part in match.groups())


def run_capture(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["LC_ALL"] = "C"
    env["LANG"] = "C"
    return subprocess.run(
        cmd,
        text=True,
        capture_output=True,
        check=False,
        env=env,
    )


def combined_output(completed: subprocess.CompletedProcess[str]) -> str:
    return "\n".join(part for part in (completed.stdout, completed.stderr) if part).strip()


def missing_landrun_flags(help_text: str) -> list[str]:
    return [flag for flag in REQUIRED_LANDRUN_FLAGS if flag not in help_text]


def landrun_install_advice() -> str:
    return "\n".join(
        [
            "Comparator currently needs a `landrun` build with `--ldd` and `--add-exec` support.",
            (
                "Released tags through `v0.1.15` are not enough to reliably satisfy comparator's"
                " sandboxing needs."
            ),
            "As of 2026-04-10, the upstream default branch is `main`, not `master`.",
            "Install or reinstall it with:",
            f"  go install github.com/zouuup/landrun/cmd/landrun@{LANDRUN_INSTALL_TARGET}",
            (
                "Version strings are not sufficient to distinguish the `v0.1.15` tag from the"
                " current `main` branch, because upstream `main` still reports `0.1.15`."
            ),
        ]
    )


def inspect_landrun() -> LandrunInspection:
    landrun_path = shutil.which("landrun")
    if landrun_path is None:
        raise RuntimeError("`landrun` was not found on PATH.\n" + landrun_install_advice())

    help_run = run_capture([landrun_path, "--help"])
    help_text = combined_output(help_run)
    if not help_text:
        help_run = run_capture([landrun_path, "-h"])
        help_text = combined_output(help_run)

    version_run = run_capture([landrun_path, "--version"])
    version_text = combined_output(version_run) or None

    return LandrunInspection(
        path=landrun_path,
        help_text=help_text,
        version_text=version_text,
        version=parse_semver(version_text or ""),
    )


def validate_landrun(inspection: LandrunInspection) -> None:
    missing_flags = missing_landrun_flags(inspection.help_text)
    if missing_flags:
        formatted = ", ".join(missing_flags)
        raise RuntimeError(
            "\n".join(
                [
                    f"`landrun` at {inspection.path} is missing comparator-required flags: {formatted}",
                    landrun_install_advice(),
                ]
            )
        )

    if inspection.version is not None and inspection.version < MIN_LANDRUN_VERSION:
        version_text = inspection.version_text or format_version(inspection.version)
        raise RuntimeError(
            "\n".join(
                [
                    f"`landrun` at {inspection.path} is too old: {version_text}",
                    (
                        "Comparator needs a `landrun` version at or above "
                        f"{format_version(MIN_LANDRUN_VERSION)}."
                    ),
                    landrun_install_advice(),
                ]
            )
        )


def ensure_landrun_compatible() -> LandrunInspection:
    inspection = inspect_landrun()
    validate_landrun(inspection)
    return inspection


def probe_landrun_with_lean_toolchain(landrun_path: str) -> None:
    lean_path = shutil.which("lean")
    if lean_path is None:
        raise RuntimeError("`lean` was not found on PATH while checking comparator prerequisites.")

    lean_prefix_run = run_capture([lean_path, "--print-prefix"])
    lean_prefix = combined_output(lean_prefix_run)
    if lean_prefix_run.returncode != 0 or not lean_prefix:
        raise RuntimeError(
            "Failed to determine the active Lean toolchain prefix with `lean --print-prefix`."
        )

    toolchain_lean = pathlib.Path(lean_prefix) / "bin" / "lean"
    if not toolchain_lean.is_file():
        raise RuntimeError(f"Lean toolchain binary not found at {toolchain_lean}.")

    completed = run_capture(
        [
            landrun_path,
            "--best-effort",
            "--ro",
            "/",
            "--rw",
            "/dev",
            "--ldd",
            "--add-exec",
            "--rox",
            lean_prefix,
            str(toolchain_lean),
            "--version",
        ]
    )
    if completed.returncode == 0:
        return

    output = combined_output(completed) or "(no output)"
    raise RuntimeError(
        "\n".join(
            [
                "`landrun` failed a Lean toolchain execution probe.",
                (
                    "Comparator needs `landrun --ldd --add-exec` to execute Lean's dynamically"
                    " linked toolchain binaries inside the sandbox."
                ),
                (
                    "Tagged `landrun` builds such as `v0.1.15` can fail here because they miss"
                    " newer ELF dependency handling present on upstream `main`."
                ),
                (
                    f"Probe command: {landrun_path} --best-effort --ro / --rw /dev --ldd "
                    f"--add-exec --rox {lean_prefix} {toolchain_lean} --version"
                ),
                f"Probe output:\n{output}",
                landrun_install_advice(),
            ]
        )
    )


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
    try:
        landrun = ensure_landrun_compatible()
        probe_landrun_with_lean_toolchain(landrun.path)
    except RuntimeError as exc:
        print(exc, file=sys.stderr)
        return 1

    if landrun.version is not None:
        print(f"Using landrun {format_version(landrun.version)} from {landrun.path}.")
    else:
        print(f"Using landrun at {landrun.path}.")

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
