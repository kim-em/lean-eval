#!/usr/bin/env python3
"""
Merge comparator results into a clone of leanprover/lean-eval-leaderboard.

Implements the sticky-no-op semantics documented at
https://github.com/leanprover/lean-eval-leaderboard (README, schema v1).
Does not run git; the caller is responsible for cloning the leaderboard
repo, committing the modified file, and pushing.
"""

from __future__ import annotations

import argparse
import datetime
import json
import pathlib
import re
import sys


SCHEMA_VERSION = 1
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
OWNER_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9._-]+$")
LOGIN_RE = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$")
SUBMISSION_KINDS = ("github_repo", "gist")
PRODUCTION_DESCRIPTION_MAX_LEN = 4000


class UpdateError(Exception):
    pass


def _require_sha(field: str, value: str) -> None:
    if not SHA_RE.fullmatch(value):
        raise UpdateError(f"{field} must be a 40-char hex SHA, got {value!r}")


def _require_owner_name(value: str) -> None:
    if not OWNER_NAME_RE.fullmatch(value):
        raise UpdateError(f"submission-repo must look like owner/name, got {value!r}")


def _require_submission_kind(value: str) -> None:
    if value not in SUBMISSION_KINDS:
        raise UpdateError(
            f"submission-kind must be one of {SUBMISSION_KINDS}, got {value!r}"
        )


def _require_login(value: str) -> None:
    if not LOGIN_RE.fullmatch(value):
        raise UpdateError(f"Invalid GitHub login: {value!r}")


def _load_existing(target_path: pathlib.Path, user: str) -> dict:
    if not target_path.is_file():
        return {"schema_version": SCHEMA_VERSION, "user": user, "solved": {}}
    try:
        data = json.loads(target_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise UpdateError(f"Invalid JSON in {target_path}: {exc}") from exc
    version = data.get("schema_version")
    if version != SCHEMA_VERSION:
        raise UpdateError(
            f"{target_path} has schema_version {version!r}; this script only knows {SCHEMA_VERSION}"
        )
    if not isinstance(data.get("user"), str):
        raise UpdateError(f"{target_path} is missing a 'user' string")
    solved = data.get("solved")
    if not isinstance(solved, dict):
        raise UpdateError(f"{target_path} is missing a 'solved' object")
    for model_key, problems in solved.items():
        if not isinstance(model_key, str) or not model_key.strip():
            raise UpdateError(f"{target_path} 'solved' has a non-string or empty model key")
        if not isinstance(problems, dict):
            raise UpdateError(
                f"{target_path} 'solved[{model_key!r}]' must be an object of problem records"
            )
    return data


def _write_json(path: pathlib.Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    contents = json.dumps(data, indent=2, sort_keys=True) + "\n"
    path.write_text(contents, encoding="utf-8")


def _commit_message(user: str, added: list[str], model: str, benchmark_commit: str) -> str:
    short = benchmark_commit[:7]
    return f"record: {user} solved {', '.join(added)} using {model} @ {short}"


def leaderboard_target_path(leaderboard_dir: pathlib.Path, user: str) -> pathlib.Path:
    return leaderboard_dir / "results" / f"{user.lower()}.json"


def update_leaderboard(
    *,
    user: str,
    leaderboard_dir: pathlib.Path,
    passed: list[str],
    benchmark_commit: str,
    submission_kind: str,
    submission_repo: str,
    submission_ref: str,
    submission_public: bool,
    model: str,
    issue_number: int,
    now: str,
    production_description: str | None = None,
) -> dict:
    _require_login(user)
    _require_sha("benchmark-commit", benchmark_commit)
    _require_sha("submission-ref", submission_ref)
    _require_submission_kind(submission_kind)
    _require_owner_name(submission_repo)
    if issue_number <= 0:
        raise UpdateError(f"issue-number must be positive, got {issue_number}")
    if not model.strip():
        raise UpdateError("model must be a non-empty string")
    if production_description is not None:
        if "\x00" in production_description:
            raise UpdateError("production-description must not contain NUL bytes")
        if len(production_description) > PRODUCTION_DESCRIPTION_MAX_LEN:
            raise UpdateError(
                f"production-description must be at most "
                f"{PRODUCTION_DESCRIPTION_MAX_LEN} characters"
            )
        if not production_description.strip():
            production_description = None

    target = leaderboard_target_path(leaderboard_dir, user)
    existing = _load_existing(target, user)
    solved = existing["solved"]
    model_bucket = solved.setdefault(model, {})
    added: list[str] = []
    for problem_id in list(dict.fromkeys(passed)):
        if problem_id in model_bucket:
            continue
        record = {
            "solved_at": now,
            "benchmark_commit": benchmark_commit,
            "submission_kind": submission_kind,
            "submission_repo": submission_repo,
            "submission_ref": submission_ref,
            "submission_public": submission_public,
            "issue_number": issue_number,
        }
        if production_description is not None:
            record["production_description"] = production_description
        model_bucket[problem_id] = record
        added.append(problem_id)

    if not model_bucket:
        # Nothing was added and the bucket we just inserted is empty
        # (model name had no new solves). Drop it to keep the file tidy.
        del solved[model]

    if added:
        _write_json(target, existing)

    return {
        "changed": bool(added),
        "added": added,
        "commit_message": _commit_message(user, added, model, benchmark_commit) if added else "",
    }


def _load_passed(path: pathlib.Path) -> list[str]:
    if not path.is_file():
        raise UpdateError(f"Results JSON not found: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise UpdateError(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict) or "passed" not in data:
        raise UpdateError(f"{path} must contain a JSON object with key 'passed'")
    passed = data["passed"]
    if not isinstance(passed, list) or not all(isinstance(p, str) for p in passed):
        raise UpdateError(f"'passed' in {path} must be a list of strings")
    return passed


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--user", required=True, help="GitHub login, preserved case.")
    parser.add_argument(
        "--leaderboard-dir",
        required=True,
        type=pathlib.Path,
        help="Path to a local clone of leanprover/lean-eval-leaderboard.",
    )
    parser.add_argument(
        "--results-json",
        required=True,
        type=pathlib.Path,
        help="Path to a JSON file of the form {'passed': [problem_id, ...]}.",
    )
    parser.add_argument("--benchmark-commit", required=True)
    parser.add_argument(
        "--submission-kind",
        required=True,
        choices=SUBMISSION_KINDS,
        help="Source kind: github_repo or gist. Determines how the leaderboard "
        "renders the proof link.",
    )
    parser.add_argument("--submission-repo", required=True)
    parser.add_argument("--submission-ref", required=True)
    parser.add_argument(
        "--submission-public",
        required=True,
        action=argparse.BooleanOptionalAction,
        help="Use --submission-public or --no-submission-public.",
    )
    parser.add_argument("--model", required=True)
    parser.add_argument("--issue-number", required=True, type=int)
    parser.add_argument(
        "--production-description",
        default=None,
        help="Optional free-form description of how the solution was produced.",
    )
    parser.add_argument(
        "--now",
        default=None,
        help="Override the ISO 8601 timestamp. Tests use this.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    try:
        args = _parse_args(argv)
        passed = _load_passed(args.results_json)
        now = args.now or datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        result = update_leaderboard(
            user=args.user,
            leaderboard_dir=args.leaderboard_dir,
            passed=passed,
            benchmark_commit=args.benchmark_commit,
            submission_kind=args.submission_kind,
            submission_repo=args.submission_repo,
            submission_ref=args.submission_ref,
            submission_public=args.submission_public,
            model=args.model,
            issue_number=args.issue_number,
            production_description=args.production_description,
            now=now,
        )
    except UpdateError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
