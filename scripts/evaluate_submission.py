#!/usr/bin/env python3
"""
Evaluate a lean-eval submission by walking cloned content for benchmark
workspaces and running comparator on each match.

This script runs inside the `evaluate` job, which holds no secrets and
no GitHub credentials. It reads a previously-cloned source tree, finds
`lakefile.toml` files whose `name` field matches a benchmark problem id,
overlays the matched `Submission.lean` + `Submission/**/*.lean` onto a
copy of the pristine `generated/<id>/` workspace, invokes
`lake exe lean-eval run-eval --json --problem <id>... --workspaces-root <tempdir>`,
and writes results.json + summary.json artifacts for the `record` job.

SECURITY: untrusted submitter Lean code is ONLY ever elaborated inside
comparator's landrun sandbox. `_prime_workspace` (below) must not invoke
`lake build` for any user-controlled target. See LANDRUN.md "What must
not regress when this is fixed" for the full rule and rationale.
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import tomllib
from typing import Iterable

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import generate_projects as gp  # noqa: E402


SUMMARY_GLOBAL_CHAR_CAP = 30_000
MAX_MISMATCHES_PER_PROBLEM = 10


class EvaluateError(Exception):
    """Structural failures that abort the whole submission evaluation."""


@dataclasses.dataclass(frozen=True)
class WorkspaceMatch:
    problem_id: str
    source_dir: pathlib.Path
    skip_reason: str | None = None


def _load_manifest_ids(manifest_path: pathlib.Path) -> set[str]:
    problems = gp.load_manifest(manifest_path)
    return {problem.id for problem in problems}


def _is_inside(path: pathlib.Path, root: pathlib.Path) -> bool:
    try:
        path.resolve(strict=False).relative_to(root.resolve(strict=False))
    except ValueError:
        return False
    return True


def _iter_lakefile_toml(source_dir: pathlib.Path) -> Iterable[pathlib.Path]:
    resolved_root = source_dir.resolve()
    stack: list[pathlib.Path] = [source_dir]
    while stack:
        current = stack.pop()
        try:
            entries = list(current.iterdir())
        except (PermissionError, FileNotFoundError) as exc:
            raise EvaluateError(f"Failed to walk {current}: {exc}") from exc
        for entry in entries:
            if entry.is_symlink():
                target = entry.resolve(strict=False)
                if not _is_inside(target, resolved_root):
                    raise EvaluateError(
                        f"Symlink {entry} escapes the submission source tree "
                        f"(resolves to {target})."
                    )
                continue  # do not follow symlinks further
            if entry.is_dir():
                stack.append(entry)
                continue
            if entry.name == "lakefile.toml":
                yield entry


def _read_lakefile_name(path: pathlib.Path) -> str | None:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        print(f"warning: failed to read {path}: {exc}", file=sys.stderr)
        return None
    try:
        data = tomllib.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, tomllib.TOMLDecodeError) as exc:
        print(f"warning: failed to parse {path}: {exc}", file=sys.stderr)
        return None
    name = data.get("name")
    if not isinstance(name, str) or not name:
        return None
    return name


def _pristine_submission_bytes(
    generated_root: pathlib.Path | None,
    problem_id: str,
) -> bytes | None:
    if generated_root is None:
        return None
    pristine = generated_root / problem_id / "Submission.lean"
    try:
        return pristine.read_bytes()
    except (FileNotFoundError, IsADirectoryError):
        return None


def detect_matches(
    source_dir: pathlib.Path,
    manifest_ids: set[str],
    *,
    generated_root: pathlib.Path | None = None,
) -> list[WorkspaceMatch]:
    """Walk source_dir for lakefile.toml files whose name matches a manifest problem id.

    A match is only valid if the containing directory also has a
    Submission.lean sibling. Duplicate problem ids across distinct
    directories are a hard failure.

    If `generated_root` is provided, candidates whose Submission.lean is
    byte-identical to `generated_root/<id>/Submission.lean` are marked with
    a skip_reason. This avoids overlaying / priming / scoring problems that
    the submitter never attempted (the common case for a fork that carries
    every generated workspace but only solves a few).
    """
    candidates: list[WorkspaceMatch] = []
    for lakefile in _iter_lakefile_toml(source_dir):
        name = _read_lakefile_name(lakefile)
        if name is None:
            continue
        if name not in manifest_ids:
            continue
        containing = lakefile.parent
        submission_lean = containing / "Submission.lean"
        if not submission_lean.is_file():
            candidates.append(
                WorkspaceMatch(
                    problem_id=name,
                    source_dir=containing,
                    skip_reason="no Submission.lean next to lakefile.toml",
                )
            )
            continue
        pristine_bytes = _pristine_submission_bytes(generated_root, name)
        if pristine_bytes is not None and not submission_lean.is_symlink():
            try:
                submitted_bytes = submission_lean.read_bytes()
            except OSError:
                submitted_bytes = None
            if submitted_bytes is not None and submitted_bytes == pristine_bytes:
                candidates.append(
                    WorkspaceMatch(
                        problem_id=name,
                        source_dir=containing,
                        skip_reason="Submission.lean unchanged from pristine; nothing to score",
                    )
                )
                continue
        candidates.append(WorkspaceMatch(problem_id=name, source_dir=containing))

    seen_by_id: dict[str, list[WorkspaceMatch]] = {}
    for candidate in candidates:
        if candidate.skip_reason is not None:
            continue
        seen_by_id.setdefault(candidate.problem_id, []).append(candidate)

    duplicates = {pid: ms for pid, ms in seen_by_id.items() if len(ms) > 1}
    if duplicates:
        lines = ["Duplicate submissions found for the same problem id:"]
        for pid, matches in duplicates.items():
            lines.append(f"  {pid}:")
            for match in matches:
                rel = match.source_dir.resolve().relative_to(source_dir.resolve())
                lines.append(f"    - {rel}")
        lines.append(
            "Each problem id must be submitted from exactly one directory. "
            "Remove or rename the duplicates and resubmit."
        )
        raise EvaluateError("\n".join(lines))

    return candidates


def _copy_tree(source: pathlib.Path, destination: pathlib.Path) -> None:
    shutil.copytree(source, destination, symlinks=False)


def _overlay_single_file(
    source: pathlib.Path,
    target: pathlib.Path,
) -> None:
    if source.is_symlink():
        raise EvaluateError(f"Refusing to overlay symlink: {source}")
    resolved_source = source.resolve(strict=True)
    if not resolved_source.is_file():
        raise EvaluateError(f"Expected a regular file at {source}, got something else")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(resolved_source, target)


def _overlay_submission_dir(
    source_submission_dir: pathlib.Path,
    target_submission_dir: pathlib.Path,
) -> list[str]:
    """Copy every .lean file under source/Submission/ into target/Submission/.

    Refuses any traversal via `..`, odd path components, or symlinks that
    resolve outside the source Submission directory.
    """
    if not source_submission_dir.is_dir():
        return []

    copied: list[str] = []
    resolved_source_root = source_submission_dir.resolve()
    resolved_target_root = target_submission_dir.resolve()

    stack: list[pathlib.Path] = [source_submission_dir]
    while stack:
        current = stack.pop()
        for entry in current.iterdir():
            if entry.is_symlink():
                resolved_entry = entry.resolve(strict=False)
                if not _is_inside(resolved_entry, resolved_source_root):
                    raise EvaluateError(
                        f"Symlink {entry} in submission escapes Submission/; "
                        f"resolves to {resolved_entry}."
                    )
                continue  # do not follow submitter-provided symlinks
            if entry.is_dir():
                stack.append(entry)
                continue
            if entry.suffix != ".lean":
                continue
            rel = entry.relative_to(source_submission_dir)
            destination = target_submission_dir / rel
            normalized_destination = pathlib.Path(os.path.normpath(destination))
            if not _is_inside(normalized_destination, resolved_target_root):
                raise EvaluateError(
                    f"Overlay path escapes target Submission/: "
                    f"{entry} would land at {normalized_destination}."
                )
            _overlay_single_file(entry, normalized_destination)
            copied.append(str(rel).replace(os.sep, "/"))
    return copied


def _share_packages(
    target: pathlib.Path,
    packages_source: pathlib.Path,
) -> str | None:
    """Symlink target/.lake/packages → packages_source to avoid duplicating
    unpacked Mathlib. Returns None on success, or a reason string if the
    share could not be set up.

    Assumes the benchmark and its generated workspaces stay in lock-step on
    every dependency rev; no rev assertion is performed.
    """
    resolved_source = packages_source.resolve()
    if not resolved_source.is_dir():
        return f"packages source {resolved_source} not a directory"

    target_lake = target / ".lake"
    target_packages = target_lake / "packages"
    target_lake.mkdir(parents=True, exist_ok=True)
    if target_packages.exists() or target_packages.is_symlink():
        if target_packages.is_symlink():
            target_packages.unlink()
        else:
            shutil.rmtree(target_packages)
    target_packages.symlink_to(resolved_source)
    return None


def _prime_workspace(target: pathlib.Path) -> None:
    """Populate the workspace's packages outside of landrun.

    Per comparator's README assumptions, `lake exe cache get` before
    invoking comparator is explicitly allowed. `lake update` is needed
    here too because comparator's landrun policy denies the
    `lake-manifest.json` writes lake update performs. Neither command
    elaborates project source files, so neither violates comparator's
    trust model.

    SECURITY: do NOT add `lake build <target>` here for any target
    whose transitive imports include `Submission` (the user-controlled
    file overlaid by overlay_match). Comparator's README assumption #2
    requires that the Solution file (and any other potentially
    adversarial file) has not been pre-compiled before comparator
    runs, because pre-compilation can let an adversarial Submission
    compromise Challenge so that comparator appears to verify a
    different theorem than the intended one. Concretely, in the
    generated workspaces `Solution` imports `Submission` and
    `Submission` imports `Submission.Helpers`, so `Solution` and
    `Submission` are off-limits here. Even `Challenge`, although it
    does not currently import `Submission`, should not be added back
    without auditing every problem's `Challenge.lean`.

    Aside from breaking comparator's correctness guarantee, building
    `Submission` outside landrun also runs arbitrary attacker IO on
    the runner: Lean elaboration executes IO via #eval, initialize,
    custom elaborators, and macros.

    Comparator's sandboxed `lake build` inside landrun is the intended
    place for `Submission` to be elaborated. Comparator + landrun (from
    upstream `main`, per its README and check_comparator_installation.py)
    is designed to handle this on a workspace primed only with `lake
    update` + `lake exe cache get`.
    """
    commands = (
        ["lake", "update"],
        ["lake", "exe", "cache", "get"],
    )
    for args in commands:
        result = subprocess.run(
            args,
            cwd=target,
            check=False,
            capture_output=True,
            text=True,
        )
        # Forward both stdout and stderr so workflow logs show the full
        # output of `lake update` + `lake exe cache get` + `lake build`
        # regardless of which stream each step chose. Lake routes
        # progress to stdout on 4.x, info: lines to stderr, etc.
        label = " ".join(args)
        print(f"--- {label} [rc={result.returncode}] ---", file=sys.stderr)
        if result.stdout and result.stdout.strip():
            print("stdout:", file=sys.stderr)
            print(result.stdout.rstrip(), file=sys.stderr)
        if result.stderr and result.stderr.strip():
            print("stderr:", file=sys.stderr)
            print(result.stderr.rstrip(), file=sys.stderr)
        print(f"--- end {label} ---", file=sys.stderr)
        if result.returncode != 0:
            stderr = (result.stderr or "").strip()
            stdout = (result.stdout or "").strip()
            details = "\n".join(part for part in [stderr, stdout] if part)
            raise EvaluateError(
                f"{' '.join(args)} failed in {target}:\n{details}"
            )


def overlay_match(
    match: WorkspaceMatch,
    *,
    generated_root: pathlib.Path,
    workspaces_root: pathlib.Path,
    shared_packages: pathlib.Path | None = None,
    prime: bool = True,
) -> dict:
    """Copy generated/<id>/ to workspaces/<id>/, overlay submitter content.

    Returns a record with fields:
      - problem_id
      - overlaid: bool
      - skip_reason: str | None
      - overlaid_files: list[str]
      - shared_packages: bool | str (True if symlinked, else reason it was not)
    """
    if match.skip_reason is not None:
        # Bail before any tree copy or package-share work — this match is
        # already known to be unactionable (e.g. submitter never modified
        # Submission.lean from the pristine version).
        return {
            "problem_id": match.problem_id,
            "overlaid": False,
            "skip_reason": match.skip_reason,
            "overlaid_files": [],
            "shared_packages": False,
        }
    target = workspaces_root / match.problem_id
    if target.exists():
        shutil.rmtree(target)
    pristine = generated_root / match.problem_id
    if not pristine.is_dir():
        return {
            "problem_id": match.problem_id,
            "overlaid": False,
            "skip_reason": f"no pristine workspace at {pristine}",
            "overlaid_files": [],
            "shared_packages": False,
        }
    _copy_tree(pristine, target)

    shared_state: bool | str = False
    if shared_packages is not None:
        reason = _share_packages(target, shared_packages)
        shared_state = True if reason is None else reason

    # 1. Overlay Submission.lean
    source_submission_lean = match.source_dir / "Submission.lean"
    if source_submission_lean.is_symlink():
        return {
            "problem_id": match.problem_id,
            "overlaid": False,
            "skip_reason": "Submission.lean is a symlink",
            "overlaid_files": [],
            "shared_packages": shared_state,
        }
    if not source_submission_lean.is_file():
        return {
            "problem_id": match.problem_id,
            "overlaid": False,
            "skip_reason": "Submission.lean missing in submitter content",
            "overlaid_files": [],
            "shared_packages": shared_state,
        }
    shutil.copyfile(source_submission_lean, target / "Submission.lean")

    # 2. Overlay Submission/**/*.lean
    overlaid_sub = _overlay_submission_dir(
        match.source_dir / "Submission",
        target / "Submission",
    )

    # 3. Assert non-empty Submission.lean post-overlay
    if not (target / "Submission.lean").is_file():
        return {
            "problem_id": match.problem_id,
            "overlaid": False,
            "skip_reason": "Submission.lean missing post-overlay (internal)",
            "overlaid_files": [],
            "shared_packages": shared_state,
        }
    if (target / "Submission.lean").stat().st_size == 0:
        return {
            "problem_id": match.problem_id,
            "overlaid": False,
            "skip_reason": "Submission.lean is empty",
            "overlaid_files": [],
            "shared_packages": shared_state,
        }

    # 4. Prime the workspace with `lake update` + `lake exe cache get`
    #    so comparator's sandboxed lake build does not try to clone
    #    packages into paths landrun will deny.
    if prime:
        _prime_workspace(target)

    return {
        "problem_id": match.problem_id,
        "overlaid": True,
        "skip_reason": None,
        "overlaid_files": ["Submission.lean"] + [f"Submission/{p}" for p in overlaid_sub],
        "shared_packages": shared_state,
    }


def _run_run_eval(
    *,
    problem_ids: list[str],
    workspaces_root: pathlib.Path,
    repo_root: pathlib.Path,
) -> dict:
    args = [
        "lake",
        "exe",
        "lean-eval",
        "run-eval",
        "--json",
        "--workspaces-root",
        str(workspaces_root),
    ]
    if problem_ids:
        # lean4-cli's `Array String` flag wants one occurrence with
        # comma-separated values; passing `--problem` repeatedly trips a
        # `Duplicate flag` parse error. Problem ids are TOML identifiers,
        # so commas never appear inside an id.
        args.extend(["--problem", ",".join(problem_ids)])
    process = subprocess.Popen(
        args,
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=None,
        text=True,
    )
    stdout, _ = process.communicate()
    stdout = (stdout or "").strip()
    if process.returncode != 0:
        details = "\n".join(
            part for part in [f"stdout:\n{stdout}" if stdout else ""] if part
        )
        raise EvaluateError(
            f"lake exe lean-eval run-eval failed with exit code {process.returncode}:\n{details}"
        )
    try:
        return json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise EvaluateError(
            f"run-eval exited 0 but produced invalid JSON ({exc}):\nstdout:\n{stdout or '(empty)'}"
        ) from exc


def _extract_passed(run_eval_output: dict) -> list[str]:
    problems = run_eval_output.get("problems")
    if not isinstance(problems, list):
        raise EvaluateError("run-eval JSON is missing `problems` list")
    passed: list[str] = []
    for entry in problems:
        if not isinstance(entry, dict):
            continue
        if entry.get("succeeded") is True:
            pid = entry.get("id")
            if isinstance(pid, str):
                passed.append(pid)
    return passed


def _cap_summary_size(summary: dict) -> dict:
    # Truncate mismatches per problem first
    problems_out = []
    for entry in summary.get("problems", []):
        trimmed = dict(entry)
        mismatches = trimmed.get("mismatches") or []
        if isinstance(mismatches, list) and len(mismatches) > MAX_MISMATCHES_PER_PROBLEM:
            trimmed["mismatches"] = mismatches[:MAX_MISMATCHES_PER_PROBLEM] + [
                f"... and {len(mismatches) - MAX_MISMATCHES_PER_PROBLEM} more"
            ]
        problems_out.append(trimmed)
    summary["problems"] = problems_out
    rendered = json.dumps(summary, sort_keys=True)
    if len(rendered) <= SUMMARY_GLOBAL_CHAR_CAP:
        return summary
    # Global cap: drop mismatches entirely from the summary until we fit
    for entry in summary["problems"]:
        entry.pop("mismatches", None)
    rendered = json.dumps(summary, sort_keys=True)
    if len(rendered) <= SUMMARY_GLOBAL_CHAR_CAP:
        summary.setdefault("notes", []).append(
            f"mismatches omitted to stay under {SUMMARY_GLOBAL_CHAR_CAP} char summary cap"
        )
        return summary
    # Last resort: truncate the problems list
    problems = summary["problems"]
    summary["problems"] = problems[:50]
    summary.setdefault("notes", []).append(
        f"summary truncated to 50 problems to stay under {SUMMARY_GLOBAL_CHAR_CAP} char cap"
    )
    return summary


def evaluate_submission(
    *,
    source_dir: pathlib.Path,
    generated_root: pathlib.Path,
    manifest_path: pathlib.Path,
    output_dir: pathlib.Path,
    repo_root: pathlib.Path,
    shared_packages: pathlib.Path | None = None,
    run_eval_runner=None,
) -> dict:
    """Run the full evaluation pipeline and write results.json + summary.json.

    `run_eval_runner` is an optional injection point for tests. If None, the
    real `lake exe lean-eval run-eval` is used.

    `shared_packages` optionally points at a directory containing an
    already-populated `.lake/packages/...` layout (e.g. the benchmark
    repo's `.lake/packages`) that per-workspace builds can reuse instead of
    re-unpacking Mathlib for each.
    """
    manifest_ids = _load_manifest_ids(manifest_path)
    matches = detect_matches(source_dir, manifest_ids, generated_root=generated_root)

    overlay_records: list[dict] = []
    # Create the tempdir as an immediate child of repo_root so that:
    #   (1) comparator's landrun sandbox, which whitelists paths rooted
    #       at the repo, can reach the per-workspace .lake/build
    #   (2) run_eval.score_problems can compute
    #       workspace_path.relative_to(gp.REPO_ROOT) without ValueError
    repo_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=repo_root, prefix=".submission-") as tmp:
        workspaces_root = pathlib.Path(tmp) / "workspaces"
        workspaces_root.mkdir(parents=True, exist_ok=True)
        overlaid_ids: list[str] = []
        for match in matches:
            record = overlay_match(
                match,
                generated_root=generated_root,
                workspaces_root=workspaces_root,
                shared_packages=shared_packages,
                # If a fake run-eval runner is injected (tests), the
                # synthetic pristine workspaces don't carry a real lakefile
                # so skip the real `lake update` + `lake exe cache get`.
                prime=run_eval_runner is None,
            )
            overlay_records.append(record)
            if record["overlaid"]:
                overlaid_ids.append(record["problem_id"])

        if not overlaid_ids:
            pristine_skipped = sum(
                1 for r in overlay_records
                if r["skip_reason"] and "unchanged from pristine" in r["skip_reason"]
            )
            extra = ""
            if pristine_skipped:
                extra = (
                    f" Found {pristine_skipped} workspace(s) whose Submission.lean "
                    "was unchanged from the pristine version; edit Submission.lean "
                    "(and any helpers under Submission/) with your proof."
                )
            raise EvaluateError(
                "No valid workspace matches found in the submission. "
                "A candidate is a directory containing a `lakefile.toml` with a `name` "
                "matching a benchmark problem id AND a non-empty `Submission.lean` sibling."
                + extra
            )

        if run_eval_runner is None:
            run_eval_output = _run_run_eval(
                problem_ids=overlaid_ids,
                workspaces_root=workspaces_root,
                repo_root=repo_root,
            )
        else:
            run_eval_output = run_eval_runner(
                problem_ids=overlaid_ids,
                workspaces_root=workspaces_root,
            )

    passed = _extract_passed(run_eval_output)

    output_dir.mkdir(parents=True, exist_ok=True)
    results = {"passed": passed}
    (output_dir / "results.json").write_text(
        json.dumps(results, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    summary = {
        "run_eval": run_eval_output,
        "overlay_records": overlay_records,
    }
    capped = _cap_summary_size(summary)
    (output_dir / "summary.json").write_text(
        json.dumps(capped, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return {"results": results, "summary": capped}


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=pathlib.Path, required=True)
    parser.add_argument("--generated-root", type=pathlib.Path, required=True)
    parser.add_argument("--manifest", type=pathlib.Path, required=True)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True)
    parser.add_argument(
        "--repo-root",
        type=pathlib.Path,
        default=gp.REPO_ROOT,
        help="Repo root where `lake exe lean-eval` should run. Defaults to detection.",
    )
    parser.add_argument(
        "--shared-packages",
        type=pathlib.Path,
        default=None,
        help=(
            "Directory containing an already-populated .lake/packages tree "
            "that per-workspace builds should reuse via symlink. Typically "
            "<repo-root>/.lake/packages. Assumes every generated workspace "
            "stays in lock-step with the benchmark on dep revs."
        ),
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    try:
        args = _parse_args(argv)
        evaluate_submission(
            source_dir=args.source_dir,
            generated_root=args.generated_root,
            manifest_path=args.manifest,
            output_dir=args.output_dir,
            repo_root=args.repo_root,
            shared_packages=args.shared_packages,
        )
    except EvaluateError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
