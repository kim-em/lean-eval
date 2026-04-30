from __future__ import annotations

import json
import io
import pathlib
import sys
import tempfile
import textwrap
import unittest
from contextlib import redirect_stderr
from unittest import mock


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
                holes = ["{pid}"]
                submitter = "tester"
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

    def test_pristine_equal_submission_lean_is_skipped(self) -> None:
        # The fork-everything-solve-a-few case: submitter's Submission.lean is
        # byte-identical to the pristine in generated/<id>/. detect_matches
        # must mark these with a skip_reason so we don't waste prime/build
        # cycles on workspaces the submitter never attempted.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated = tmp_path / "generated"
            _write_pristine(generated, "two_plus_two")
            src = tmp_path / "src"
            _write_submitter_workspace(
                src, ".", "two_plus_two",
                submission_lean_contents="sorry\n",
            )
            matches = ev.detect_matches(
                src, {"two_plus_two"}, generated_root=generated,
            )
        self.assertEqual(len(matches), 1)
        self.assertIn("unchanged from pristine", matches[0].skip_reason or "")

    def test_modified_submission_lean_is_not_skipped_as_pristine(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated = tmp_path / "generated"
            _write_pristine(generated, "two_plus_two")
            src = tmp_path / "src"
            _write_submitter_workspace(src, ".", "two_plus_two")
            matches = ev.detect_matches(
                src, {"two_plus_two"}, generated_root=generated,
            )
        self.assertEqual(len(matches), 1)
        self.assertIsNone(matches[0].skip_reason)

    def test_pristine_check_off_when_no_generated_root(self) -> None:
        # Backward compat: callers that don't pass generated_root must still
        # see byte-identical Submission.lean as a real candidate, not a skip.
        with tempfile.TemporaryDirectory() as tmp:
            src = pathlib.Path(tmp) / "src"
            _write_submitter_workspace(
                src, ".", "two_plus_two", submission_lean_contents="sorry\n",
            )
            matches = ev.detect_matches(src, {"two_plus_two"})
        self.assertEqual(len(matches), 1)
        self.assertIsNone(matches[0].skip_reason)


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
                match,
                generated_root=generated,
                workspaces_root=workspaces,
                prime=False,
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
                prime=False,
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
                match,
                generated_root=generated,
                workspaces_root=workspaces,
                prime=False,
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
                prime=False,
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

    def test_fork_everything_solve_a_few(self) -> None:
        # Mirrors the real submission case from issue #20: a fork that
        # carries every generated workspace but only solves a subset.
        # Pristine workspaces must be detected and skipped; only the
        # actually-attempted workspaces should reach the run-eval call.
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated, manifest = self._setup_repo_like(tmp_path)
            problem_ids = ["alpha", "beta", "gamma", "delta", "epsilon"]
            for pid in problem_ids:
                _write_pristine(generated, pid)
            _write_manifest(manifest, problem_ids)
            src = tmp_path / "src"
            for pid in problem_ids:
                # All five workspaces present in the fork.
                _write_submitter_workspace(
                    src, pid, pid,
                    submission_lean_contents="sorry\n",
                )
            # Only beta and delta have real submissions.
            (src / "beta" / "Submission.lean").write_text(
                "by exact submitter.proof\n", encoding="utf-8"
            )
            (src / "delta" / "Submission.lean").write_text(
                "by exact submitter.proof\n", encoding="utf-8"
            )
            output = tmp_path / "out"

            seen_problem_ids: list[list[str]] = []

            def runner(*, problem_ids: list[str], workspaces_root: pathlib.Path) -> dict:
                seen_problem_ids.append(list(problem_ids))
                return _fake_runner_factory(["beta"])(
                    problem_ids=problem_ids, workspaces_root=workspaces_root
                )

            result = ev.evaluate_submission(
                source_dir=src,
                generated_root=generated,
                manifest_path=manifest,
                output_dir=output,
                repo_root=tmp_path,
                run_eval_runner=runner,
            )
        self.assertEqual(len(seen_problem_ids), 1)
        self.assertEqual(sorted(seen_problem_ids[0]), ["beta", "delta"])
        self.assertEqual(result["results"]["passed"], ["beta"])

    def test_fork_with_no_real_submissions_explains_pristine_skip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            generated, manifest = self._setup_repo_like(tmp_path)
            _write_pristine(generated, "two_plus_two")
            _write_manifest(manifest, ["two_plus_two"])
            src = tmp_path / "src"
            _write_submitter_workspace(
                src, ".", "two_plus_two",
                submission_lean_contents="sorry\n",
            )
            output = tmp_path / "out"
            with self.assertRaisesRegex(ev.EvaluateError, "unchanged from the pristine"):
                ev.evaluate_submission(
                    source_dir=src,
                    generated_root=generated,
                    manifest_path=manifest,
                    output_dir=output,
                    repo_root=tmp_path,
                    run_eval_runner=_fake_runner_factory([]),
                )

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


class RunEvalInvocationTests(unittest.TestCase):
    def test_run_eval_streams_stderr_and_parses_stdout_json(self) -> None:
        class FakeProcess:
            def __init__(self) -> None:
                self.returncode = 0

            def communicate(self) -> tuple[str, None]:
                print("live comparator output", file=sys.stderr)
                return ('{"problems": [{"id": "two_plus_two", "succeeded": true}]}', None)

        with tempfile.TemporaryDirectory() as tmp:
            repo_root = pathlib.Path(tmp)
            stderr = io.StringIO()
            with mock.patch.object(ev.subprocess, "Popen", return_value=FakeProcess()) as popen:
                with redirect_stderr(stderr):
                    result = ev._run_run_eval(
                        problem_ids=["two_plus_two"],
                        workspaces_root=repo_root / "workspaces",
                        repo_root=repo_root,
                    )

        self.assertEqual(result["problems"][0]["id"], "two_plus_two")
        self.assertIn("live comparator output", stderr.getvalue())
        _, kwargs = popen.call_args
        self.assertIs(kwargs["stderr"], None)
        self.assertEqual(kwargs["stdout"], ev.subprocess.PIPE)

    def test_run_eval_passes_problem_ids_as_single_comma_separated_flag(self) -> None:
        # lean4-cli's `Array String` flag instance does NOT support
        # `--problem foo --problem bar` (it raises `Duplicate flag`). It
        # parses one occurrence as a comma-separated list. _run_run_eval
        # must produce the comma-separated form so the Lean side accepts
        # multi-problem evaluations.
        class FakeProcess:
            def __init__(self) -> None:
                self.returncode = 0

            def communicate(self) -> tuple[str, None]:
                return ('{"problems": []}', None)

        with tempfile.TemporaryDirectory() as tmp:
            repo_root = pathlib.Path(tmp)
            with mock.patch.object(ev.subprocess, "Popen", return_value=FakeProcess()) as popen:
                ev._run_run_eval(
                    problem_ids=["foo", "bar", "baz"],
                    workspaces_root=repo_root / "workspaces",
                    repo_root=repo_root,
                )
        argv = popen.call_args[0][0]
        problem_indices = [i for i, a in enumerate(argv) if a == "--problem"]
        self.assertEqual(len(problem_indices), 1, f"--problem must appear exactly once, got argv={argv}")
        self.assertEqual(argv[problem_indices[0] + 1], "foo,bar,baz")

    def test_run_eval_omits_problem_flag_when_no_ids(self) -> None:
        class FakeProcess:
            def __init__(self) -> None:
                self.returncode = 0

            def communicate(self) -> tuple[str, None]:
                return ('{"problems": []}', None)

        with tempfile.TemporaryDirectory() as tmp:
            repo_root = pathlib.Path(tmp)
            with mock.patch.object(ev.subprocess, "Popen", return_value=FakeProcess()) as popen:
                ev._run_run_eval(
                    problem_ids=[],
                    workspaces_root=repo_root / "workspaces",
                    repo_root=repo_root,
                )
        argv = popen.call_args[0][0]
        self.assertNotIn("--problem", argv)

    def test_run_eval_nonzero_exit_includes_stdout(self) -> None:
        class FakeProcess:
            def __init__(self) -> None:
                self.returncode = 1

            def communicate(self) -> tuple[str, None]:
                return ("failure details", None)

        with tempfile.TemporaryDirectory() as tmp:
            repo_root = pathlib.Path(tmp)
            with mock.patch.object(ev.subprocess, "Popen", return_value=FakeProcess()):
                with self.assertRaisesRegex(ev.EvaluateError, "failure details"):
                    ev._run_run_eval(
                        problem_ids=["two_plus_two"],
                        workspaces_root=repo_root / "workspaces",
                        repo_root=repo_root,
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
