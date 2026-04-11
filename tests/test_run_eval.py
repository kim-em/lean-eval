from __future__ import annotations

import pathlib
import sys
import tempfile
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import generate_projects as gp  # noqa: E402
import run_eval as reval  # noqa: E402


def _write_stub_ilean(repo_root: pathlib.Path, module_name: str) -> None:
    parts = module_name.split(".")
    ilean_path = repo_root.joinpath(
        ".lake", "build", "lib", "lean", *parts[:-1], f"{parts[-1]}.ilean"
    )
    ilean_path.parent.mkdir(parents=True, exist_ok=True)
    ilean_path.write_text('{"references": {}, "decls": {}}', encoding="utf-8")


class RunEvalTests(unittest.TestCase):
    def test_problem_attempt_mismatches_empty_for_pristine_workspace(self) -> None:
        problem = gp.ProblemSpec(
            id="demo",
            title="Demo",
            test=True,
            module="Demo.Module",
            theorem="demo_theorem",
            author="Kim",
        )
        extracted = gp.ExtractedTheorem(
            declaration_name="Demo.demo_theorem",
            module=problem.module,
            source_range=(1, 0, 2, 9),
        )
        toolchain = "leanprover/lean4:v4.30.0-rc1\n"

        with tempfile.TemporaryDirectory() as tmpdir:
            repo_root = pathlib.Path(tmpdir)
            generated_root = repo_root / "generated"
            problem_dir = generated_root / problem.id
            source_path = repo_root / "Demo" / "Module.lean"
            source_path.parent.mkdir(parents=True, exist_ok=True)
            source_path.write_text(
                "theorem demo_theorem : True := by\n  trivial\n",
                encoding="utf-8",
            )
            _write_stub_ilean(repo_root, problem.module)
            old_repo_root = gp.REPO_ROOT
            old_generated_root = gp.GENERATED_ROOT
            old_source_path = gp.module_source_path
            try:
                gp.REPO_ROOT = repo_root
                gp.GENERATED_ROOT = generated_root
                gp.module_source_path = lambda _module_name: source_path
                dependency = gp.DependencySpec(
                    name="mathlib",
                    git="https://github.com/leanprover-community/mathlib4.git",
                    rev="v4.30.0-rc1",
                )
                files = gp.render_workspace(problem, extracted, toolchain, dependency)
                for relative_path, content in files.items():
                    destination = problem_dir / relative_path
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_text(content, encoding="utf-8")
                (repo_root / "lean-toolchain").write_text(toolchain, encoding="utf-8")
                mismatches = reval.problem_attempt_mismatches(
                    problem,
                    extractor=lambda _problem: extracted,
                    workspaces_root=repo_root / "workspaces",
                )
            finally:
                gp.REPO_ROOT = old_repo_root
                gp.GENERATED_ROOT = old_generated_root
                gp.module_source_path = old_source_path

            self.assertEqual(mismatches, [])

    def test_score_problems_counts_attempts_and_successes(self) -> None:
        problems = [
            gp.ProblemSpec(
                id="attempted_pass",
                title="Attempted pass",
                test=True,
                module="M",
                theorem="t1",
                author="Kim",
            ),
            gp.ProblemSpec(
                id="attempted_fail",
                title="Attempted fail",
                test=False,
                module="M",
                theorem="t2",
                author="Kim",
            ),
            gp.ProblemSpec(
                id="untouched",
                title="Untouched",
                test=False,
                module="M",
                theorem="t3",
                author="Kim",
            ),
        ]

        mismatch_map = {
            "attempted_pass": ["stale generated/attempted_pass/Submission.lean"],
            "attempted_fail": ["stale generated/attempted_fail/Submission.lean"],
            "untouched": [],
        }
        exit_codes = {"attempted_pass": 0, "attempted_fail": 1}

        scores = reval.score_problems(
            problems,
            mismatch_detector=lambda problem: mismatch_map[problem.id],
            test_runner=lambda problem_id: exit_codes[problem_id],
        )

        self.assertEqual([score.attempted for score in scores], [True, True, False])
        self.assertEqual([score.succeeded for score in scores], [True, False, False])
        self.assertEqual(scores[0].mismatches, mismatch_map["attempted_pass"])
        self.assertEqual(scores[2].exit_code, None)
        self.assertEqual(scores[0].workspace_path, "generated/attempted_pass")
        self.assertEqual(scores[2].workspace_path, "generated/untouched")

    def test_summarize_scores(self) -> None:
        scores = [
            reval.ProblemScore(
                id="a",
                title="A",
                test=True,
                attempted=True,
                succeeded=True,
                exit_code=0,
                mismatches=["stale generated/a/Submission.lean"],
                workspace_path="generated/a",
            ),
            reval.ProblemScore(
                id="b",
                title="B",
                test=False,
                attempted=True,
                succeeded=False,
                exit_code=1,
                mismatches=["stale generated/b/Submission.lean"],
                workspace_path="generated/b",
            ),
            reval.ProblemScore(
                id="c",
                title="C",
                test=False,
                attempted=False,
                succeeded=False,
                exit_code=None,
                mismatches=[],
                workspace_path="generated/c",
            ),
        ]
        summary = reval.summarize_scores(scores)
        self.assertEqual(summary["total_problems"], 3)
        self.assertEqual(summary["attempted_problems"], 2)
        self.assertEqual(summary["succeeded_problems"], 1)
        self.assertEqual(summary["attempted_test_problems"], 1)
        self.assertEqual(summary["succeeded_test_problems"], 1)
        self.assertEqual(summary["attempted_main_problems"], 1)
        self.assertEqual(summary["succeeded_main_problems"], 0)

    def test_render_human_summary_includes_test_and_main_totals(self) -> None:
        scores = [
            reval.ProblemScore(
                id="a",
                title="A",
                test=True,
                attempted=True,
                succeeded=True,
                exit_code=0,
                mismatches=["stale generated/a/Submission.lean"],
                workspace_path="generated/a",
            ),
            reval.ProblemScore(
                id="b",
                title="B",
                test=False,
                attempted=True,
                succeeded=False,
                exit_code=1,
                mismatches=["stale generated/b/Submission.lean"],
                workspace_path="generated/b",
            ),
            reval.ProblemScore(
                id="c",
                title="C",
                test=False,
                attempted=False,
                succeeded=False,
                exit_code=None,
                mismatches=[],
                workspace_path="generated/c",
            ),
        ]
        summary = reval.summarize_scores(scores)
        rendered = reval.render_human_summary(scores, summary)
        self.assertIn("Attempted 2 / 3 problems; succeeded on 1.", rendered)
        self.assertIn("Test problems: attempted 1; succeeded on 1.", rendered)
        self.assertIn("Main benchmark problems: attempted 1; succeeded on 0.", rendered)
        self.assertIn("- a [test]: passed", rendered)
        self.assertIn("- b [main]: failed", rendered)
        self.assertIn("- c [main]: unattempted", rendered)

    def test_workspace_path_for_problem_prefers_local_workspace(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_root = pathlib.Path(tmpdir)
            workspaces_root = repo_root / "workspaces"
            generated_root = repo_root / "generated"
            (workspaces_root / "demo").mkdir(parents=True)
            (generated_root / "demo").mkdir(parents=True)
            old_generated_root = gp.GENERATED_ROOT
            try:
                gp.GENERATED_ROOT = generated_root
                selected = reval.workspace_path_for_problem(
                    "demo", workspaces_root=workspaces_root
                )
            finally:
                gp.GENERATED_ROOT = old_generated_root

            self.assertEqual(selected, workspaces_root / "demo")

    def test_problem_attempt_mismatches_uses_local_workspace_when_present(self) -> None:
        problem = gp.ProblemSpec(
            id="demo",
            title="Demo",
            test=True,
            module="Demo.Module",
            theorem="demo_theorem",
            author="Kim",
        )
        extracted = gp.ExtractedTheorem(
            declaration_name="Demo.demo_theorem",
            module=problem.module,
            source_range=(1, 0, 2, 9),
        )
        toolchain = "leanprover/lean4:v4.30.0-rc1\n"
        dependency = gp.DependencySpec(
            name="mathlib",
            git="https://github.com/leanprover-community/mathlib4.git",
            rev="v4.30.0-rc1",
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            repo_root = pathlib.Path(tmpdir)
            generated_root = repo_root / "generated"
            workspaces_root = repo_root / "workspaces"
            generated_problem_dir = generated_root / problem.id
            workspace_problem_dir = workspaces_root / problem.id
            source_path = repo_root / "Demo" / "Module.lean"
            source_path.parent.mkdir(parents=True, exist_ok=True)
            source_path.write_text(
                "theorem demo_theorem : True := by\n  trivial\n",
                encoding="utf-8",
            )
            _write_stub_ilean(repo_root, problem.module)
            old_repo_root = gp.REPO_ROOT
            old_generated_root = gp.GENERATED_ROOT
            old_source_path = gp.module_source_path
            try:
                gp.REPO_ROOT = repo_root
                gp.GENERATED_ROOT = generated_root
                gp.module_source_path = lambda _module_name: source_path
                files = gp.render_workspace(problem, extracted, toolchain, dependency)
                for base_dir in [generated_problem_dir, workspace_problem_dir]:
                    for relative_path, content in files.items():
                        destination = base_dir / relative_path
                        destination.parent.mkdir(parents=True, exist_ok=True)
                        destination.write_text(content, encoding="utf-8")
                submission_path = workspace_problem_dir / "Submission.lean"
                submission_path.write_text(
                    submission_path.read_text(encoding="utf-8").replace("  sorry\n", "  trivial\n", 1),
                    encoding="utf-8",
                )
                (repo_root / "lean-toolchain").write_text(toolchain, encoding="utf-8")
                mismatches = reval.problem_attempt_mismatches(
                    problem,
                    extractor=lambda _problem: extracted,
                    workspaces_root=workspaces_root,
                )
            finally:
                gp.REPO_ROOT = old_repo_root
                gp.GENERATED_ROOT = old_generated_root
                gp.module_source_path = old_source_path

            self.assertEqual(mismatches, [f"stale workspaces/demo/Submission.lean"])


if __name__ == "__main__":
    unittest.main()
