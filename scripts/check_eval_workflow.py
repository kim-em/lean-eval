#!/usr/bin/env python3
"""
Run an end-to-end local eval workflow check against the benchmark.
"""

from __future__ import annotations

import pathlib
import shutil
import sys
import tempfile

import generate_projects as gp
import run_eval as reval


REPO_ROOT = gp.REPO_ROOT
TWO_PLUS_TWO_ID = "two_plus_two"


class WorkflowCheckError(RuntimeError):
    pass


def ensure_repo_clean() -> None:
    try:
        gp.generate(
            manifest_path=gp.DEFAULT_MANIFEST,
            selected_problem_id=None,
            check=True,
        )
    except gp.GenerationError as exc:
        raise WorkflowCheckError(
            "Repository is not in a clean generated state.\n"
            "Run `python scripts/generate_projects.py` to refresh generated workspaces, "
            "then rerun this check.\n\n"
            f"Details:\n{exc}"
        ) from exc


def load_problems() -> list[gp.ProblemSpec]:
    problems = gp.load_manifest(gp.DEFAULT_MANIFEST)
    gp.validate_problems(problems)
    gp.validate_manifest_against_inventory(problems)
    gp.build_extractor(problems)
    return problems


def summarize_with_temp_workspaces(
    problems: list[gp.ProblemSpec],
    workspaces_root: pathlib.Path,
) -> dict[str, object]:
    scores = reval.score_problems(problems, workspaces_root=workspaces_root)
    return reval.summarize_scores(scores)


def assert_counts(
    summary: dict[str, object],
    *,
    attempted: int,
    succeeded: int,
    label: str,
) -> None:
    actual_attempted = int(summary["attempted_problems"])
    actual_succeeded = int(summary["succeeded_problems"])
    if actual_attempted != attempted or actual_succeeded != succeeded:
        raise WorkflowCheckError(
            f"{label} produced unexpected results.\n"
            f"Expected attempted={attempted}, succeeded={succeeded}.\n"
            f"Actual summary:\n{summary}"
        )


def prepare_two_plus_two_workspace(workspaces_root: pathlib.Path) -> pathlib.Path:
    source = gp.GENERATED_ROOT / TWO_PLUS_TWO_ID
    if not source.is_dir():
        raise WorkflowCheckError(f"Missing generated workspace: {source}")
    destination = workspaces_root / TWO_PLUS_TWO_ID
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination)
    return destination


def replace_placeholder(workspace: pathlib.Path, replacement: str) -> None:
    submission_path = workspace / "Submission.lean"
    original = submission_path.read_text(encoding="utf-8")
    placeholder = "  sorry\n"
    if placeholder not in original:
        raise WorkflowCheckError(f"Expected placeholder proof in {submission_path}")
    submission_path.write_text(
        original.replace(placeholder, replacement, 1),
        encoding="utf-8",
    )


def main() -> int:
    try:
        ensure_repo_clean()
        problems = load_problems()
        # Place the tempdir under REPO_ROOT so `run_eval.score_problems` can
        # compute `workspace_path.relative_to(gp.REPO_ROOT)` without ValueError
        # (same workaround as `evaluate_submission.py`).
        with tempfile.TemporaryDirectory(
            prefix="lean-eval-workflow-", dir=gp.REPO_ROOT
        ) as tmpdir:
            workspaces_root = pathlib.Path(tmpdir) / "workspaces"

            initial_summary = summarize_with_temp_workspaces(problems, workspaces_root)
            assert_counts(initial_summary, attempted=0, succeeded=0, label="Pristine eval")

            workspace = prepare_two_plus_two_workspace(workspaces_root)
            replace_placeholder(
                workspace,
                "  exact (by omega : (2 : Nat) + 2 = 5)\n",
            )
            incorrect_summary = summarize_with_temp_workspaces(problems, workspaces_root)
            assert_counts(
                incorrect_summary,
                attempted=1,
                succeeded=0,
                label="Incorrect two_plus_two attempt",
            )

            shutil.rmtree(workspace)
            workspace = prepare_two_plus_two_workspace(workspaces_root)
            replace_placeholder(workspace, "  norm_num\n")
            correct_summary = summarize_with_temp_workspaces(problems, workspaces_root)
            assert_counts(
                correct_summary,
                attempted=1,
                succeeded=1,
                label="Correct two_plus_two attempt",
            )

        print("Eval workflow check passed.")
        return 0
    except (WorkflowCheckError, gp.GenerationError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
