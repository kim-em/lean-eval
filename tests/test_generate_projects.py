from __future__ import annotations

import pathlib
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import generate_projects as gp  # noqa: E402


class GenerateProjectsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        subprocess.run(
            ["lake", "build", "FormalMathEval.EasyProblems", "extract_theorem"],
            cwd=REPO_ROOT,
            check=True,
        )

    def test_invalid_problem_id(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_path = pathlib.Path(tmpdir) / "problems.toml"
            manifest_path.write_text(
                """
version = 1

[[problem]]
id = "bad/id"
title = "Bad"
module = "FormalMathEval.EasyProblems"
theorem = "two_plus_two_eq_four"
submitter = "Kim"
""".strip()
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(gp.GenerationError, "invalid"):
                gp.load_manifest(manifest_path)

    def test_duplicate_problem_id_rejected(self) -> None:
        problems = [
            gp.ProblemSpec(
                id="two_plus_two",
                title="A",
                test=False,
                module="M",
                theorem="t1",
                submitter="Kim",
            ),
            gp.ProblemSpec(
                id="two_plus_two",
                title="B",
                test=False,
                module="M",
                theorem="t2",
                submitter="Kim",
            ),
        ]
        with self.assertRaisesRegex(gp.GenerationError, "Duplicate problem id"):
            gp.validate_problems(problems)

    def test_duplicate_theorem_reference_rejected(self) -> None:
        problems = [
            gp.ProblemSpec(
                id="a",
                title="A",
                test=False,
                module="M",
                theorem="t",
                submitter="Kim",
            ),
            gp.ProblemSpec(
                id="b",
                title="B",
                test=False,
                module="M",
                theorem="t",
                submitter="Kim",
            ),
        ]
        with self.assertRaisesRegex(gp.GenerationError, "Duplicate theorem reference"):
            gp.validate_problems(problems)

    def test_unique_modules_preserves_order(self) -> None:
        problems = [
            gp.ProblemSpec(id="a", title="A", test=False, module="M1", theorem="t1", submitter="Kim"),
            gp.ProblemSpec(id="b", title="B", test=False, module="M2", theorem="t2", submitter="Kim"),
            gp.ProblemSpec(id="c", title="C", test=False, module="M1", theorem="t3", submitter="Kim"),
        ]
        self.assertEqual(gp.unique_modules(problems), ["M1", "M2"])

    def test_extract_statement_text_slices_source_range(self) -> None:
        problem = gp.ProblemSpec(
            id="two_plus_two",
            title="2 + 2 = 4",
            test=True,
            module="FormalMathEval.EasyProblems",
            theorem="two_plus_two_eq_four",
            submitter="Kim",
        )
        extracted = gp.ExtractedTheorem(
            declaration_name="FormalMathEval.two_plus_two_eq_four",
            module=problem.module,
            source_range=(13, 0, 15, 7),
            same_module_dependencies=(),
        )
        statement = gp.extract_statement_text(problem, extracted)
        self.assertEqual(statement, ": (2 : Nat) + 2 = 4")

    def test_render_workspace_uses_local_theorem_name(self) -> None:
        problem = gp.ProblemSpec(
            id="two_plus_two",
            title="2 + 2 = 4",
            test=True,
            module="FormalMathEval.EasyProblems",
            theorem="two_plus_two_eq_four",
            submitter="Kim",
        )
        extracted = gp.ExtractedTheorem(
            declaration_name="FormalMathEval.two_plus_two_eq_four",
            module=problem.module,
            source_range=(13, 0, 15, 7),
            same_module_dependencies=(),
        )
        dependency = gp.DependencySpec(
            name="mathlib",
            git="https://github.com/leanprover-community/mathlib4.git",
            rev="example-rev",
        )
        files = gp.render_workspace(
            problem,
            extracted,
            "leanprover/lean4:v4.30.0-rc1\n",
            dependency,
        )
        self.assertIn("theorem two_plus_two_eq_four", files["Challenge.lean"])
        self.assertIn("Submission.two_plus_two_eq_four", files["Solution.lean"])
        self.assertIn(": (2 : Nat) + 2 = 4 := by", files["Challenge.lean"])
        self.assertIn(
            "theorem two_plus_two_eq_four : (2 : Nat) + 2 = 4 := by",
            files["Solution.lean"],
        )
        self.assertIn(
            "exact Submission.two_plus_two_eq_four",
            files["Solution.lean"],
        )
        self.assertIn("- Test Problem: yes", files["README.md"])
        self.assertIn('rev = "example-rev"', files["lakefile.toml"])

    def test_check_workspace_detects_stale_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            problem_dir = pathlib.Path(tmpdir) / "two_plus_two"
            problem_dir.mkdir(parents=True)
            expected = {"README.md": "fresh\n"}
            (problem_dir / "README.md").write_text("stale\n", encoding="utf-8")
            mismatches = gp.check_workspace(problem_dir, expected)
            self.assertEqual(mismatches, [f"stale {problem_dir / 'README.md'}"])

    def test_extract_theorem_accepts_full_name(self) -> None:
        extracted = gp.extract_theorem(
            gp.ProblemSpec(
                id="two_plus_two",
                title="2 + 2 = 4",
                test=True,
                module="FormalMathEval.EasyProblems",
                theorem="FormalMathEval.two_plus_two_eq_four",
                submitter="Kim",
            )
        )
        self.assertEqual(extracted.declaration_name, "FormalMathEval.two_plus_two_eq_four")
        self.assertEqual(len(extracted.source_range), 4)

    def test_extract_theorem_rejects_unknown_declaration(self) -> None:
        with self.assertRaisesRegex(gp.GenerationError, "not found"):
            gp.extract_theorem(
                gp.ProblemSpec(
                    id="missing",
                    title="Missing",
                    test=False,
                    module="FormalMathEval.EasyProblems",
                    theorem="does_not_exist",
                    submitter="Kim",
                )
            )

    def test_extract_theorem_rejects_non_theorem(self) -> None:
        with self.assertRaisesRegex(gp.GenerationError, "not a theorem"):
            gp.extract_theorem(
                gp.ProblemSpec(
                    id="starter_number",
                    title="starterNumber",
                    test=False,
                    module="FormalMathEval.EasyProblems",
                    theorem="starterNumber",
                    submitter="Kim",
                )
            )

    def test_manifest_rejects_non_boolean_test_field(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_path = pathlib.Path(tmpdir) / "problems.toml"
            manifest_path.write_text(
                """
version = 1

[[problem]]
id = "bad_test_flag"
title = "Bad"
test = "yes"
module = "FormalMathEval.EasyProblems"
theorem = "two_plus_two_eq_four"
submitter = "Kim"
""".strip()
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(gp.GenerationError, "non-boolean field 'test'"):
                gp.load_manifest(manifest_path)

    def test_load_root_mathlib_dependency(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            lakefile_path = pathlib.Path(tmpdir) / "lakefile.toml"
            lakefile_path.write_text(
                """
name = "demo"

[[require]]
name = "mathlib"
git = "https://github.com/leanprover-community/mathlib4.git"
rev = "v4.test"
""".strip()
                + "\n",
                encoding="utf-8",
            )
            dependency = gp.load_root_mathlib_dependency(lakefile_path)
            self.assertEqual(dependency.name, "mathlib")
            self.assertEqual(
                dependency.git, "https://github.com/leanprover-community/mathlib4.git"
            )
            self.assertEqual(dependency.rev, "v4.test")

if __name__ == "__main__":
    unittest.main()
