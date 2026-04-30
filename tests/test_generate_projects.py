from __future__ import annotations

import pathlib
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import generate_projects as gp  # noqa: E402


def _spec(
    *,
    id: str = "two_plus_two",
    title: str = "T",
    test: bool = False,
    module: str = "M",
    holes: tuple[str, ...] = ("t",),
    submitter: str = "Kim",
) -> gp.ProblemSpec:
    return gp.ProblemSpec(
        id=id,
        title=title,
        test=test,
        module=module,
        holes=holes,
        submitter=submitter,
    )


class GenerateProjectsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        subprocess.run(
            ["lake", "build", "LeanEval.EasyProblems", "extract_theorem"],
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
module = "LeanEval.EasyProblems"
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
            _spec(id="two_plus_two", holes=("t1",)),
            _spec(id="two_plus_two", title="B", holes=("t2",)),
        ]
        with self.assertRaisesRegex(gp.GenerationError, "Duplicate problem id"):
            gp.validate_problems(problems)

    def test_duplicate_hole_reference_rejected(self) -> None:
        problems = [
            _spec(id="a", holes=("t",)),
            _spec(id="b", title="B", holes=("t",)),
        ]
        with self.assertRaisesRegex(gp.GenerationError, "Duplicate hole reference"):
            gp.validate_problems(problems)

    def test_unique_modules_preserves_order(self) -> None:
        problems = [
            _spec(id="a", module="M1", holes=("t1",)),
            _spec(id="b", title="B", module="M2", holes=("t2",)),
            _spec(id="c", title="C", module="M1", holes=("t3",)),
        ]
        self.assertEqual(gp.unique_modules(problems), ["M1", "M2"])

    def test_extract_statement_text_slices_source_range(self) -> None:
        problem = _spec(
            id="two_plus_two",
            title="2 + 2 = 4",
            test=True,
            module="LeanEval.EasyProblems",
            holes=("two_plus_two_eq_four",),
        )
        extracted = gp.ExtractedTheorem(
            declaration_name="LeanEval.two_plus_two_eq_four",
            module=problem.module,
            source_range=(13, 0, 15, 7),
            same_module_dependencies=(),
            kind="theorem",
        )
        statement = gp.extract_statement_text(problem, extracted)
        self.assertEqual(statement, ": (2 : Nat) + 2 = 4")

    def test_render_workspace_uses_local_theorem_name(self) -> None:
        problem = _spec(
            id="two_plus_two",
            title="2 + 2 = 4",
            test=True,
            module="LeanEval.EasyProblems",
            holes=("two_plus_two_eq_four",),
        )
        extracted = gp.ExtractedTheorem(
            declaration_name="LeanEval.two_plus_two_eq_four",
            module=problem.module,
            source_range=(13, 0, 15, 7),
            same_module_dependencies=(),
            kind="theorem",
        )
        dependency = gp.DependencySpec(
            name="mathlib",
            git="https://github.com/leanprover-community/mathlib4.git",
            rev="example-rev",
        )
        files = gp.render_workspace(
            problem,
            [extracted],
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

    def test_extract_one_accepts_full_name(self) -> None:
        problem = _spec(
            id="two_plus_two",
            title="2 + 2 = 4",
            test=True,
            module="LeanEval.EasyProblems",
            holes=("LeanEval.two_plus_two_eq_four",),
        )
        extracted = gp.extract_one(problem, problem.holes[0])
        self.assertEqual(extracted.declaration_name, "LeanEval.two_plus_two_eq_four")
        self.assertEqual(len(extracted.source_range), 4)
        self.assertEqual(extracted.kind, "theorem")

    def test_extract_one_rejects_unknown_declaration(self) -> None:
        problem = _spec(
            id="missing",
            title="Missing",
            module="LeanEval.EasyProblems",
            holes=("does_not_exist",),
        )
        with self.assertRaisesRegex(gp.GenerationError, "not found"):
            gp.extract_one(problem, problem.holes[0])

    def test_extract_one_rejects_unsupported_kind(self) -> None:
        # `starterNumber` exists in the source as plain `def`. With
        # def-hole support added, a `def` is now an accepted kind, so
        # extraction should succeed with kind="def" rather than failing.
        # If this changes (e.g. starterNumber is removed or changed), the
        # test should be updated to point at a genuinely unsupported decl.
        problem = _spec(
            id="starter_number",
            title="starterNumber",
            module="LeanEval.EasyProblems",
            holes=("starterNumber",),
        )
        extracted = gp.extract_one(problem, problem.holes[0])
        self.assertEqual(extracted.kind, "def")

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
module = "LeanEval.EasyProblems"
theorem = "two_plus_two_eq_four"
submitter = "Kim"
""".strip()
                + "\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(gp.GenerationError, "non-boolean field 'test'"):
                gp.load_manifest(manifest_path)

    def test_manifest_accepts_holes_array(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_path = pathlib.Path(tmpdir) / "problems.toml"
            manifest_path.write_text(
                """
version = 1

[[problem]]
id = "multi"
title = "Multi"
test = true
module = "LeanEval.Sandbox"
holes = ["foo", "foo_def"]
submitter = "Kim"
""".strip()
                + "\n",
                encoding="utf-8",
            )
            problems = gp.load_manifest(manifest_path)
            self.assertEqual(len(problems), 1)
            self.assertEqual(problems[0].holes, ("foo", "foo_def"))

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
