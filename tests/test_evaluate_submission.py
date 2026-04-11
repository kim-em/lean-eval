from __future__ import annotations

import json
import pathlib
import sys
import tempfile
import textwrap
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import evaluate_submission as ev  # noqa: E402


def _write_pristine(generated_root: pathlib.Path, problem_id: str) -> None:
    target = generated_root / problem_id
    target.mkdir(parents=True)
    (target / "lakefile.toml").write_text(
        f'name = "{problem_id}"\n', encoding="utf-8"
    )
    (target / "Challenge.lean").write_text("-- challenge\n", encoding="utf-8")
    (target / "Solution.lean").write_text("-- trusted solution\n", encoding="utf-8")
    (target / "Submission.lean").write_text("sorry\n", encoding="utf-8")
    submission_dir = target / "Submission"
    submission_dir.mkdir()
    (submission_dir / "Helpers.lean").write_text("-- pristine helper\n", encoding="utf-8")


def _write_submitter_workspace(
    root: pathlib.Path,
    rel_dir: str,
    problem_id: str,
    *,
    include_submission_dir: bool = False,
    submission_lean_contents: str | None = "by exact submitter.proof\n",
    extra_files: dict[str, str] | None = None,
) -> pathlib.Path:
    target = root / rel_dir
    target.mkdir(parents=True, exist_ok=True)
    (target / "lakefile.toml").write_text(
        f'name = "{problem_id}"\n', encoding="utf-8"
    )
    if submission_lean_contents is not None:
        (target / "Submission.lean").write_text(submission_lean_contents, encoding="utf-8")
    if include_submission_dir:
        sub = target / "Submission"
        sub.mkdir()
        (sub / "Helpers.lean").write_text("-- submitter helper\n", encoding="utf-8")
    if extra_files:
        for rel, contents in extra_files.items():
            path = target / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents, encoding="utf-8")
    return target


def _write_manifest(path: pathlib.Path, problem_ids: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    blocks = []
    for pid in problem_ids:
        blocks.append(
            textwrap.dedent(
                f"""\
                [[problem]]
                id = "{pid}"
                title = "{pid}"
                test = false
                module = "Fake.{pid}"
                theorem = "{pid}"
                author = "tester"
                """
            )
        )
    path.write_text("\n".join(blocks), encoding="utf-8")


def _fake_runner_factory(pass_ids: list[str]):
    def runner(*, problem_ids: list[str], workspaces_root: pathlib.Path) -> dict:
        return {
            "total_problems": len(problem_ids),
            "attempted_problems": len(problem_ids),
            "succeeded_problems": len([pid for pid in problem_ids if pid in pass_ids]),
            "problems": [
                {
                    "id": pid,
                    "title": pid,
                    "test": False,
                    "attempted": True,
                    "succeeded": pid in pass_ids,
                    "exit_code": 0 if pid in pass_ids else 1,
                    "mismatches": [],
                    "workspace_path": f"workspaces/{pid}",
                }
                for pid in problem_ids
            ],
        }
    return runner


class DetectMatchesTests(unittest.TestCase):
    def test_single_workspace_match(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            src = pathlib.Path(tmp) / "src"
            _write_submitter_workspace(src, ".", "two_plus_two")
            matches = ev.detect_matches(src, {"two_plus_two"})
        self.assertEqual(len(matches), 1)
        self.assertEqual(matches[0].problem_id, "two_plus_two")
        self.assertIsNone(matches[0].skip_reason)

    def test_multi_workspace_match(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            src = pathlib.Path(tmp) / "src"
            _write_submitter_workspace(src, "a", "two_plus_two")
            _write_submitter_workspace(src, "b", "list_append_singleton_length")
            matches = ev.detect_matches(
                src, {"two_plus_two", "list_append_singleton_length"}
            )
        self.assertEqual(
            sorted(m.problem_id for m in matches),
            ["list_append_singleton_length", "two_plus_two"],
        )

    def test_lakefile_without_submission_is_skipped_with_reason(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            src = pathlib.Path(tmp) / "src"
            _write_submitter_workspace(
                src, ".", "two_plus_two", submission_lean_contents=None
            )
            matches = ev.detect_matches(src, {"two_plus_two"})
        self.assertEqual(len(matches), 1)
        self.assertIsNotNone(matches[0].skip_reason)

    def test_unknown_problem_id_is_silently_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            src = pathlib.Path(tmp) / "src"
            _write_submitter_workspace(src, ".", "not_a_real_problem")
            matches = ev.detect_matches(src, {"two_plus_two"})
        self.assertEqual(matches, [])

    def test_duplicate_problem_id_is_hard_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            src = pathlib.Path(tmp) / "src"
            _write_submitter_workspace(src, "foo", "two_plus_two")
            _write_submitter_workspace(src, "bar", "two_plus_two")
            with self.assertRaisesRegex(ev.EvaluateError, "Duplicate"):
                ev.detect_matches(src, {"two_plus_two"})

    def test_malformed_lakefile_is_warn_and_skip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            src = pathlib.Path(tmp) / "src"
            _write_submitter_workspace(src, "good", "two_plus_two")
            bad = src / "bad"
            bad.mkdir()
            (bad / "lakefile.toml").write_text("not [ valid toml\n", encoding="utf-8")
            matches = ev.detect_matches(src, {"two_plus_two"})
        self.assertEqual([m.problem_id for m in matches], ["two_plus_two"])

    def test_symlink_escape_in_walk_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            outside = tmp_path / "outside"
            outside.mkdir()
            (outside / "secret.txt").write_text("shhh")
            src = tmp_path / "src"
            src.mkdir()
            (src / "link").symlink_to(outside)
            with self.assertRaisesRegex(ev.EvaluateError, "escapes"):
                list(ev._iter_lakefile_toml(src))


class OverlayMatchTests(unittest.TestCase):
    def test_overlay_copies_submission_lean_and_subdir(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated = tmp_path / "generated"
            _write_pristine(generated, "two_plus_two")
            src = tmp_path / "src"
            _write_submitter_workspace(
                src, ".", "two_plus_two", include_submission_dir=True
            )
            workspaces = tmp_path / "ws"
            workspaces.mkdir()
            match = ev.WorkspaceMatch(
                problem_id="two_plus_two",
                source_dir=src,
            )
            record = ev.overlay_match(
                match, generated_root=generated, workspaces_root=workspaces
            )
            self.assertTrue(record["overlaid"])
            target = workspaces / "two_plus_two"
            self.assertEqual(
                (target / "Submission.lean").read_text(),
                "by exact submitter.proof\n",
            )
            self.assertEqual(
                (target / "Submission" / "Helpers.lean").read_text(),
                "-- submitter helper\n",
            )
            # Solution.lean must come from the pristine workspace, not the submitter.
            self.assertEqual(
                (target / "Solution.lean").read_text(),
                "-- trusted solution\n",
            )

    def test_solution_lean_in_submitter_content_is_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated = tmp_path / "generated"
            _write_pristine(generated, "two_plus_two")
            src = tmp_path / "src"
            _write_submitter_workspace(
                src,
                ".",
                "two_plus_two",
                extra_files={"Solution.lean": "-- EVIL cheating proof\n"},
            )
            workspaces = tmp_path / "ws"
            workspaces.mkdir()
            record = ev.overlay_match(
                ev.WorkspaceMatch(problem_id="two_plus_two", source_dir=src),
                generated_root=generated,
                workspaces_root=workspaces,
            )
            self.assertTrue(record["overlaid"])
            self.assertEqual(
                (workspaces / "two_plus_two" / "Solution.lean").read_text(),
                "-- trusted solution\n",
            )

    def test_overlay_skipped_if_submission_lean_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated = tmp_path / "generated"
            _write_pristine(generated, "two_plus_two")
            src = tmp_path / "src"
            _write_submitter_workspace(
                src, ".", "two_plus_two", submission_lean_contents=None
            )
            workspaces = tmp_path / "ws"
            workspaces.mkdir()
            match = ev.WorkspaceMatch(
                problem_id="two_plus_two",
                source_dir=src,
                skip_reason="no Submission.lean next to lakefile.toml",
            )
            record = ev.overlay_match(
                match, generated_root=generated, workspaces_root=workspaces
            )
        self.assertFalse(record["overlaid"])
        self.assertIn("Submission.lean", record["skip_reason"])

    def test_empty_submission_lean_is_excluded(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated = tmp_path / "generated"
            _write_pristine(generated, "two_plus_two")
            src = tmp_path / "src"
            _write_submitter_workspace(
                src, ".", "two_plus_two", submission_lean_contents=""
            )
            workspaces = tmp_path / "ws"
            workspaces.mkdir()
            record = ev.overlay_match(
                ev.WorkspaceMatch(problem_id="two_plus_two", source_dir=src),
                generated_root=generated,
                workspaces_root=workspaces,
            )
        self.assertFalse(record["overlaid"])
        self.assertIn("empty", record["skip_reason"])

    def test_overlay_rejects_submission_symlink_escape(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated = tmp_path / "generated"
            _write_pristine(generated, "two_plus_two")
            src = tmp_path / "src"
            outside = tmp_path / "outside"
            outside.mkdir()
            (outside / "evil.lean").write_text("-- evil\n", encoding="utf-8")
            _write_submitter_workspace(src, ".", "two_plus_two", include_submission_dir=True)
            (src / "Submission" / "link.lean").unlink() if (src / "Submission" / "link.lean").exists() else None
            (src / "Submission" / "escape.lean").symlink_to(outside / "evil.lean")
            workspaces = tmp_path / "ws"
            workspaces.mkdir()
            with self.assertRaisesRegex(ev.EvaluateError, "escapes Submission/"):
                ev.overlay_match(
                    ev.WorkspaceMatch(problem_id="two_plus_two", source_dir=src),
                    generated_root=generated,
                    workspaces_root=workspaces,
                )


class EvaluateSubmissionEndToEndTests(unittest.TestCase):
    def _setup_repo_like(self, tmp_path: pathlib.Path) -> tuple[pathlib.Path, pathlib.Path]:
        generated = tmp_path / "generated"
        manifest = tmp_path / "manifests" / "problems.toml"
        return generated, manifest

    def test_single_problem_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated, manifest = self._setup_repo_like(tmp_path)
            _write_pristine(generated, "two_plus_two")
            _write_manifest(manifest, ["two_plus_two"])
            src = tmp_path / "src"
            _write_submitter_workspace(src, ".", "two_plus_two")
            output = tmp_path / "out"
            result = ev.evaluate_submission(
                source_dir=src,
                generated_root=generated,
                manifest_path=manifest,
                output_dir=output,
                repo_root=tmp_path,
                run_eval_runner=_fake_runner_factory(["two_plus_two"]),
            )
            self.assertEqual(result["results"]["passed"], ["two_plus_two"])
            disk_results = json.loads((output / "results.json").read_text())
            self.assertEqual(disk_results, {"passed": ["two_plus_two"]})

    def test_multi_problem_mixed_results(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated, manifest = self._setup_repo_like(tmp_path)
            _write_pristine(generated, "two_plus_two")
            _write_pristine(generated, "list_append_singleton_length")
            _write_manifest(manifest, ["two_plus_two", "list_append_singleton_length"])
            src = tmp_path / "src"
            _write_submitter_workspace(src, "a", "two_plus_two")
            _write_submitter_workspace(src, "b", "list_append_singleton_length")
            output = tmp_path / "out"
            result = ev.evaluate_submission(
                source_dir=src,
                generated_root=generated,
                manifest_path=manifest,
                output_dir=output,
                repo_root=tmp_path,
                run_eval_runner=_fake_runner_factory(["two_plus_two"]),
            )
        self.assertEqual(result["results"]["passed"], ["two_plus_two"])

    def test_no_matches_is_hard_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated, manifest = self._setup_repo_like(tmp_path)
            _write_pristine(generated, "two_plus_two")
            _write_manifest(manifest, ["two_plus_two"])
            src = tmp_path / "src"
            src.mkdir()
            (src / "README.md").write_text("nothing here")
            output = tmp_path / "out"
            with self.assertRaisesRegex(ev.EvaluateError, "No valid workspace matches"):
                ev.evaluate_submission(
                    source_dir=src,
                    generated_root=generated,
                    manifest_path=manifest,
                    output_dir=output,
                    repo_root=tmp_path,
                    run_eval_runner=_fake_runner_factory([]),
                )


class SummaryCapTests(unittest.TestCase):
    def test_truncates_per_problem_mismatches(self) -> None:
        summary = {
            "problems": [
                {
                    "id": "x",
                    "mismatches": [f"m{i}" for i in range(25)],
                }
            ]
        }
        capped = ev._cap_summary_size(summary)
        self.assertTrue(len(capped["problems"][0]["mismatches"]) <= 11)
        self.assertIn(
            "and 15 more",
            capped["problems"][0]["mismatches"][-1],
        )


if __name__ == "__main__":
    unittest.main()
