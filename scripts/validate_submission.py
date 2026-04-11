#!/usr/bin/env python3
"""
Validate that a submission only edits participant-owned files.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
import pathlib
import re
import subprocess
import sys

import generate_projects as gp


PATTERN_RULES: list[tuple[re.Pattern[str], frozenset[str]]] = [
    (re.compile(r"^generated/[^/]+/Solution\.lean$"), frozenset({"M"})),
    (re.compile(r"^generated/[^/]+/Submission\.lean$"), frozenset({"M"})),
    (re.compile(r"^generated/[^/]+/Submission/.+\.lean$"), frozenset({"A", "C", "D", "M", "R"})),
    (
        re.compile(r"^generated/[^/]+/(?!README\.md$).+\.md$"),
        frozenset({"A"}),
    ),
    (re.compile(r"^generated/[^/]+/LICEN[CS]E$"), frozenset({"A"})),
]
ALL_ALLOWED_STATUSES: frozenset[str] = frozenset(
    status for _, statuses in PATTERN_RULES for status in statuses
)


@dataclass(frozen=True)
class SubmissionChange:
    status: str
    paths: tuple[str, ...]


def changed_files_from_git(base_ref: str, head_ref: str) -> list[SubmissionChange]:
    result = subprocess.run(
        [
            "git",
            "diff",
            "--find-renames",
            "--find-copies",
            "--name-status",
            "-z",
            f"{base_ref}..{head_ref}",
        ],
        cwd=gp.REPO_ROOT,
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", errors="replace").strip()
        stdout = result.stdout.decode("utf-8", errors="replace").strip()
        details = "\n".join(part for part in [stderr, stdout] if part)
        raise gp.GenerationError(f"git diff failed:\n{details}")
    return parse_name_status_output(result.stdout)


def parse_name_status_output(raw_output: bytes) -> list[SubmissionChange]:
    text = raw_output.decode("utf-8", errors="surrogateescape")
    fields = [field for field in text.split("\0") if field]
    changes: list[SubmissionChange] = []
    index = 0
    while index < len(fields):
        status = fields[index]
        index += 1
        if not status:
            continue
        status_code = status[0]
        path_count = 2 if status_code in {"R", "C"} else 1
        if index + path_count > len(fields):
            raise gp.GenerationError(f"Malformed git diff --name-status output near status '{status}'")
        paths = tuple(fields[index : index + path_count])
        index += path_count
        changes.append(SubmissionChange(status=status, paths=paths))
    return changes


def normalize_submission_path(path: str) -> str:
    pure_path = pathlib.PurePosixPath(path)
    if pure_path.is_absolute():
        raise gp.GenerationError(f"Submission path must be relative to the repo root: {path}")
    if any(part in {"..", ""} for part in pure_path.parts):
        raise gp.GenerationError(f"Submission path is not a clean relative repo path: {path}")
    normalized = pure_path.as_posix()
    if normalized == ".":
        raise gp.GenerationError("Submission path cannot be the repository root.")
    return normalized


def path_policy_error(path: str, status_code: str, valid_problem_ids: set[str]) -> str | None:
    normalized = normalize_submission_path(path)
    matching_statuses: set[str] = set()
    for pattern, statuses in PATTERN_RULES:
        if pattern.fullmatch(normalized):
            matching_statuses.update(statuses)
    if not matching_statuses:
        return "path is outside the submission whitelist"
    parts = normalized.split("/")
    if len(parts) < 3 or parts[1] not in valid_problem_ids:
        return "path does not belong to a known generated problem workspace"
    if status_code not in matching_statuses:
        return (
            f"change status '{status_code}' is not allowed for this path; "
            f"allowed: {sorted(matching_statuses)}"
        )
    return None


def flatten_touched_paths(changes: list[SubmissionChange]) -> list[str]:
    paths: list[str] = []
    for change in changes:
        for path in change.paths:
            paths.append(normalize_submission_path(path))
    return paths


def validate_changed_files(
    changes: list[SubmissionChange],
) -> tuple[list[SubmissionChange], list[dict[str, object]]]:
    problems = gp.load_manifest(gp.DEFAULT_MANIFEST)
    valid_problem_ids = {problem.id for problem in problems}
    allowed: list[SubmissionChange] = []
    forbidden: list[dict[str, object]] = []

    for change in changes:
        status_code = change.status[0]
        reasons: list[str] = []
        normalized_paths: list[str] = []
        for path in change.paths:
            try:
                normalized = normalize_submission_path(path)
            except gp.GenerationError as exc:
                reasons.append(str(exc))
                normalized_paths.append(path)
                continue
            normalized_paths.append(normalized)
            reason = path_policy_error(normalized, status_code, valid_problem_ids)
            if reason is not None:
                reasons.append(f"{normalized}: {reason}")

        if status_code not in ALL_ALLOWED_STATUSES:
            reasons.append(f"unsupported git change status '{change.status}'")

        if reasons:
            forbidden.append(
                {
                    "status": change.status,
                    "paths": normalized_paths,
                    "reasons": reasons,
                }
            )
        else:
            allowed.append(SubmissionChange(status=change.status, paths=tuple(normalized_paths)))

    return allowed, forbidden


def parse_explicit_file_changes(files: list[str]) -> list[SubmissionChange]:
    return [SubmissionChange(status="M", paths=(file_path,)) for file_path in files]


def serialize_change(change: SubmissionChange) -> dict[str, object]:
    return {
        "status": change.status,
        "paths": list(change.paths),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", help="Base git ref for changed-file validation.")
    parser.add_argument("--head", help="Head git ref for changed-file validation.")
    parser.add_argument(
        "--file",
        action="append",
        default=[],
        help="Explicit changed file path. Can be passed multiple times.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON output.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.file:
            changes = parse_explicit_file_changes(args.file)
        elif args.base and args.head:
            changes = changed_files_from_git(args.base, args.head)
        else:
            raise gp.GenerationError("Provide either --base/--head or one or more --file arguments.")

        allowed, forbidden = validate_changed_files(changes)
    except gp.GenerationError as exc:
        if args.json:
            print(json.dumps({"status": "error", "message": str(exc)}, indent=2))
        else:
            print(str(exc), file=sys.stderr)
        return 1

    status = 0 if not forbidden else 1
    payload = {
        "status": "ok" if status == 0 else "forbidden_changes",
        "changes": [serialize_change(change) for change in changes],
        "changed_files": flatten_touched_paths(changes),
        "allowed_changes": [serialize_change(change) for change in allowed],
        "allowed_files": flatten_touched_paths(allowed),
        "forbidden_changes": forbidden,
        "forbidden_files": [
            path
            for entry in forbidden
            for path in entry["paths"]
        ],
    }
    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        if forbidden:
            print("Forbidden submission changes detected:", file=sys.stderr)
            for entry in forbidden:
                print(
                    f"{entry['status']} {' -> '.join(entry['paths'])}",
                    file=sys.stderr,
                )
                for reason in entry["reasons"]:
                    print(f"  - {reason}", file=sys.stderr)
        else:
            print("Submission changes are limited to participant-owned files.")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
