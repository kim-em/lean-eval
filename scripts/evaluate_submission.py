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


def detect_matches(
    source_dir: pathlib.Path,
    manifest_ids: set[str],
) -> list[WorkspaceMatch]:
    """Walk source_dir for lakefile.toml files whose name matches a manifest problem id.

    A match is only valid if the containing directory also has a
    Submission.lean sibling. Duplicate problem ids across distinct
    directories are a hard failure.
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


def overlay_match(
    match: WorkspaceMatch,
    *,
    generated_root: pathlib.Path,
    workspaces_root: pathlib.Path,
) -> dict:
    """Copy generated/<id>/ to workspaces/<id>/, overlay submitter content.

    Returns a record with fields:
      - problem_id
      - overlaid: bool
      - skip_reason: str | None
      - overlaid_files: list[str]
    """
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
        }
    _copy_tree(pristine, target)

    if match.skip_reason is not None:
        return {
            "problem_id": match.problem_id,
            "overlaid": False,
            "skip_reason": match.skip_reason,
            "overlaid_files": [],
        }

    # 1. Overlay Submission.lean
    source_submission_lean = match.source_dir / "Submission.lean"
    if source_submission_lean.is_symlink():
        return {
            "problem_id": match.problem_id,
            "overlaid": False,
            "skip_reason": "Submission.lean is a symlink",
            "overlaid_files": [],
        }
    if not source_submission_lean.is_file():
        return {
            "problem_id": match.problem_id,
            "overlaid": False,
            "skip_reason": "Submission.lean missing in submitter content",
            "overlaid_files": [],
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
        }
    if (target / "Submission.lean").stat().st_size == 0:
        return {
            "problem_id": match.problem_id,
            "overlaid": False,
            "skip_reason": "Submission.lean is empty",
            "overlaid_files": [],
        }

    return {
        "problem_id": match.problem_id,
        "overlaid": True,
        "skip_reason": None,
        "overlaid_files": ["Submission.lean"] + [f"Submission/{p}" for p in overlaid_sub],
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
    for pid in problem_ids:
        args.extend(["--problem", pid])
    result = subprocess.run(
        args,
        cwd=repo_root,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        details = "\n".join(part for part in [stderr, stdout] if part)
        raise EvaluateError(f"lake exe lean-eval run-eval failed:\n{details}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise EvaluateError(f"run-eval produced invalid JSON: {exc}") from exc


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
    run_eval_runner=None,
) -> dict:
    """Run the full evaluation pipeline and write results.json + summary.json.

    `run_eval_runner` is an optional injection point for tests. If None, the
    real `lake exe lean-eval run-eval` is used.
    """
    manifest_ids = _load_manifest_ids(manifest_path)
    matches = detect_matches(source_dir, manifest_ids)

    overlay_records: list[dict] = []
    with tempfile.TemporaryDirectory() as tmp:
        workspaces_root = pathlib.Path(tmp) / "workspaces"
        workspaces_root.mkdir(parents=True, exist_ok=True)
        overlaid_ids: list[str] = []
        for match in matches:
            record = overlay_match(
                match,
                generated_root=generated_root,
                workspaces_root=workspaces_root,
            )
            overlay_records.append(record)
            if record["overlaid"]:
                overlaid_ids.append(record["problem_id"])

        if not overlaid_ids:
            raise EvaluateError(
                "No valid workspace matches found in the submission. "
                "A candidate is a directory containing a `lakefile.toml` with a `name` "
                "matching a benchmark problem id AND a non-empty `Submission.lean` sibling."
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
        )
    except EvaluateError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
