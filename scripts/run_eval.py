#!/usr/bin/env python3
"""
Score local generated workspaces by counting attempted problems and comparator successes.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import os
import pathlib
import subprocess
import sys
from dataclasses import asdict, dataclass
from typing import Callable, Iterator

import generate_projects as gp

DEFAULT_WORKSPACES_ROOT = gp.REPO_ROOT / "workspaces"


@dataclass(frozen=True)
class ProblemScore:
    id: str
    title: str
    test: bool
    attempted: bool
    succeeded: bool
    exit_code: int | None
    mismatches: list[str]
    workspace_path: str


def expected_workspace_files(
    problem: gp.ProblemSpec,
    *,
    extractor: Callable[[gp.ProblemSpec, str], gp.ExtractedTheorem],
) -> dict[str, str]:
    toolchain = (gp.REPO_ROOT / "lean-toolchain").read_text(encoding="utf-8")
    mathlib_dependency = gp.load_root_mathlib_dependency()
    extracteds = [extractor(problem, hole) for hole in problem.holes]
    return gp.render_workspace(problem, extracteds, toolchain, mathlib_dependency)


def workspace_path_for_problem(
    problem_id: str,
    *,
    workspaces_root: pathlib.Path = DEFAULT_WORKSPACES_ROOT,
) -> pathlib.Path:
    workspace_path = workspaces_root / problem_id
    if workspace_path.is_dir():
        return workspace_path
    return gp.GENERATED_ROOT / problem_id


def problem_attempt_mismatches(
    problem: gp.ProblemSpec,
    *,
    extractor: Callable[[gp.ProblemSpec, str], gp.ExtractedTheorem],
    workspaces_root: pathlib.Path = DEFAULT_WORKSPACES_ROOT,
) -> list[str]:
    expected_files = expected_workspace_files(problem, extractor=extractor)
    return gp.check_workspace(
        workspace_path_for_problem(problem.id, workspaces_root=workspaces_root),
        expected_files,
    )


def run_problem_test(
    problem_id: str,
    *,
    workspaces_root: pathlib.Path = DEFAULT_WORKSPACES_ROOT,
) -> int:
    problem_dir = workspace_path_for_problem(problem_id, workspaces_root=workspaces_root)
    # Forward lake test output to this process's stderr so it does not
    # pollute stdout, which must stay clean for --json callers.
    completed = subprocess.run(
        ["lake", "test"],
        cwd=problem_dir,
        env=os.environ.copy(),
        text=True,
        check=False,
        stdout=sys.stderr,
        stderr=sys.stderr,
    )
    return completed.returncode


def score_problems(
    problems: list[gp.ProblemSpec],
    *,
    extractor: Callable[[gp.ProblemSpec, str], gp.ExtractedTheorem] = gp.extract_one,
    workspaces_root: pathlib.Path = DEFAULT_WORKSPACES_ROOT,
    mismatch_detector: Callable[[gp.ProblemSpec], list[str]] | None = None,
    test_runner: Callable[[str], int] = run_problem_test,
) -> list[ProblemScore]:
    scores: list[ProblemScore] = []
    if mismatch_detector is None:
        mismatch_detector = lambda problem: problem_attempt_mismatches(
            problem,
            extractor=extractor,
            workspaces_root=workspaces_root,
        )
    default_test_runner = test_runner is run_problem_test
    for problem in problems:
        mismatches = mismatch_detector(problem)
        attempted = bool(mismatches)
        workspace_path = workspace_path_for_problem(problem.id, workspaces_root=workspaces_root)
        if attempted:
            if default_test_runner:
                exit_code = run_problem_test(problem.id, workspaces_root=workspaces_root)
            else:
                exit_code = test_runner(problem.id)
            succeeded = exit_code == 0
        else:
            exit_code = None
            succeeded = False
        scores.append(
            ProblemScore(
                id=problem.id,
                title=problem.title,
                test=problem.test,
                attempted=attempted,
                succeeded=succeeded,
                exit_code=exit_code,
                mismatches=mismatches,
                workspace_path=str(workspace_path.relative_to(gp.REPO_ROOT)),
            )
        )
    return scores


def summarize_scores(scores: list[ProblemScore]) -> dict[str, object]:
    attempted = [score for score in scores if score.attempted]
    succeeded = [score for score in attempted if score.succeeded]
    return {
        "total_problems": len(scores),
        "attempted_problems": len(attempted),
        "succeeded_problems": len(succeeded),
        "attempted_test_problems": sum(score.attempted and score.test for score in scores),
        "succeeded_test_problems": sum(score.succeeded and score.test for score in scores),
        "attempted_main_problems": sum(score.attempted and not score.test for score in scores),
        "succeeded_main_problems": sum(score.succeeded and not score.test for score in scores),
        "problems": [asdict(score) for score in scores],
    }


def render_human_summary(scores: list[ProblemScore], summary: dict[str, object]) -> str:
    lines = [
        (
            f"Attempted {summary['attempted_problems']} / {summary['total_problems']} problems; "
            f"succeeded on {summary['succeeded_problems']}."
        ),
        (
            f"Test problems: attempted {summary['attempted_test_problems']}; "
            f"succeeded on {summary['succeeded_test_problems']}."
        ),
        (
            f"Main benchmark problems: attempted {summary['attempted_main_problems']}; "
            f"succeeded on {summary['succeeded_main_problems']}."
        ),
    ]
    for score in scores:
        if not score.attempted:
            status = "unattempted"
        elif score.succeeded:
            status = "passed"
        else:
            status = "failed"
        test_marker = "test" if score.test else "main"
        lines.append(f"- {score.id} [{test_marker}]: {status}")
    return "\n".join(lines)


def selected_problems(all_problems: list[gp.ProblemSpec], selected_ids: list[str]) -> list[gp.ProblemSpec]:
    if not selected_ids:
        return all_problems
    wanted = set(selected_ids)
    selected = [problem for problem in all_problems if problem.id in wanted]
    missing = sorted(wanted - {problem.id for problem in selected})
    if missing:
        raise gp.GenerationError(f"Unknown problem id(s): {', '.join(missing)}")
    return selected


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--manifest",
        default=str(gp.DEFAULT_MANIFEST),
        help="Path to the problem manifest.",
    )
    parser.add_argument(
        "--problem",
        action="append",
        default=[],
        help="Restrict scoring to the given problem id. Can be passed multiple times.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON output.",
    )
    parser.add_argument(
        "--workspaces-root",
        default=str(DEFAULT_WORKSPACES_ROOT),
        help="Directory containing local problem workspaces. Defaults to ./workspaces.",
    )
    return parser.parse_args()


@contextlib.contextmanager
def _stdout_to_stderr() -> Iterator[None]:
    """Redirect file-descriptor 1 (stdout) to file-descriptor 2 (stderr).

    Needed because lake build invocations from generate_projects.py inherit
    stdout from the Python process, and their "Replayed" / "Built" progress
    lines pollute stdout even after we redirect Python's `print`. We do
    this at the file-descriptor level so subprocess children inherit the
    redirected fd.
    """
    saved = os.dup(sys.stdout.fileno())
    try:
        os.dup2(sys.stderr.fileno(), sys.stdout.fileno())
        yield
    finally:
        sys.stdout.flush()
        os.dup2(saved, sys.stdout.fileno())
        os.close(saved)


def main() -> int:
    args = parse_args()
    try:
        problems = gp.load_manifest(pathlib.Path(args.manifest))
        gp.validate_problems(problems)
        # Validate against the full manifest so that per-module inventory
        # checks do not trip when --problem filters to a subset.
        #
        # In --json mode, redirect stdout to stderr for everything until
        # we have the final summary, so that lake build progress lines
        # do not pollute the JSON payload we emit.
        if args.json:
            with _stdout_to_stderr():
                gp.validate_manifest_against_inventory(problems)
                problems = selected_problems(problems, args.problem)
                gp.build_extractor(problems)
                scores = score_problems(
                    problems,
                    workspaces_root=pathlib.Path(args.workspaces_root),
                )
                summary = summarize_scores(scores)
        else:
            gp.validate_manifest_against_inventory(problems)
            problems = selected_problems(problems, args.problem)
            gp.build_extractor(problems)
            scores = score_problems(
                problems,
                workspaces_root=pathlib.Path(args.workspaces_root),
            )
            summary = summarize_scores(scores)
    except gp.GenerationError as exc:
        if args.json:
            print(json.dumps({"status": "error", "message": str(exc)}, indent=2))
        else:
            print(str(exc), file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(summary, indent=2))
        return 0

    print(render_human_summary(scores, summary))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
