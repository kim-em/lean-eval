from __future__ import annotations

import json
import pathlib
import sys
import tempfile
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import update_leaderboard as ul  # noqa: E402


BENCHMARK_COMMIT = "8e1b9cf5e1d3c2b1a0f9e8d7c6b5a4938271605f"
SUBMISSION_REF = "deadbeefcafef00dbaadc0de1234567890abcdef"


def default_call(
    *,
    leaderboard_dir: pathlib.Path,
    passed: list[str],
    user: str = "alice",
    now: str = "2026-04-11T10:45:00Z",
    submission_public: bool = True,
    model: str = "Claude Opus 4.6",
    issue_number: int = 42,
    benchmark_commit: str = BENCHMARK_COMMIT,
    production_description: str | None = None,
) -> dict:
    return ul.update_leaderboard(
        user=user,
        leaderboard_dir=leaderboard_dir,
        passed=passed,
        benchmark_commit=benchmark_commit,
        submission_repo="alice/proofs",
        submission_ref=SUBMISSION_REF,
        submission_public=submission_public,
        model=model,
        issue_number=issue_number,
        production_description=production_description,
        now=now,
    )


class UpdateLeaderboardTests(unittest.TestCase):
    def test_first_write_creates_file_with_schema_v1(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            result = default_call(leaderboard_dir=lb, passed=["two_plus_two"])
            self.assertTrue(result["changed"])
            self.assertEqual(result["added"], ["two_plus_two"])
            self.assertEqual(
                result["commit_message"],
                "record: alice solved two_plus_two @ 8e1b9cf",
            )
            target = lb / "results" / "alice.json"
            self.assertTrue(target.is_file())
            data = json.loads(target.read_text())
            self.assertEqual(data["schema_version"], 1)
            self.assertEqual(data["user"], "alice")
            record = data["solved"]["two_plus_two"]
            self.assertEqual(record["solved_at"], "2026-04-11T10:45:00Z")
            self.assertEqual(record["benchmark_commit"], BENCHMARK_COMMIT)
            self.assertEqual(record["submission_repo"], "alice/proofs")
            self.assertEqual(record["submission_ref"], SUBMISSION_REF)
            self.assertTrue(record["submission_public"])
            self.assertEqual(record["model"], "Claude Opus 4.6")
            self.assertEqual(record["issue_number"], 42)
            self.assertNotIn("production_description", record)

    def test_duplicate_is_noop_and_preserves_solved_at(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            default_call(leaderboard_dir=lb, passed=["two_plus_two"], now="2026-04-11T10:45:00Z")
            result = default_call(leaderboard_dir=lb, passed=["two_plus_two"], now="2026-05-01T00:00:00Z")
            self.assertFalse(result["changed"])
            self.assertEqual(result["added"], [])
            self.assertEqual(result["commit_message"], "")
            data = json.loads((lb / "results" / "alice.json").read_text())
            self.assertEqual(data["solved"]["two_plus_two"]["solved_at"], "2026-04-11T10:45:00Z")

    def test_partial_add_only_records_new_problems(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            default_call(leaderboard_dir=lb, passed=["two_plus_two"])
            result = default_call(leaderboard_dir=lb, passed=["two_plus_two", "list_append_singleton_length"])
            self.assertEqual(result["added"], ["list_append_singleton_length"])
            self.assertEqual(
                result["commit_message"],
                "record: alice solved list_append_singleton_length @ 8e1b9cf",
            )

    def test_multi_problem_commit_message(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            result = default_call(leaderboard_dir=lb, passed=["a", "b", "c"])
            self.assertEqual(result["added"], ["a", "b", "c"])
            self.assertEqual(result["commit_message"], "record: alice solved a, b, c @ 8e1b9cf")

    def test_private_submission_records_false_flag(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            default_call(leaderboard_dir=lb, passed=["secret"], submission_public=False)
            record = json.loads((lb / "results" / "alice.json").read_text())["solved"]["secret"]
            self.assertFalse(record["submission_public"])

    def test_duplicates_in_passed_list_are_deduped(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            result = default_call(leaderboard_dir=lb, passed=["a", "a", "b"])
            self.assertEqual(result["added"], ["a", "b"])

    def test_filename_is_lowercased(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            default_call(leaderboard_dir=lb, passed=["x"], user="Kim-EM")
            self.assertTrue((lb / "results" / "kim-em.json").is_file())
            data = json.loads((lb / "results" / "kim-em.json").read_text())
            self.assertEqual(data["user"], "Kim-EM")

    def test_schema_version_mismatch_is_fatal(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            target = lb / "results" / "alice.json"
            target.parent.mkdir(parents=True)
            target.write_text(json.dumps({"schema_version": 999, "user": "alice", "solved": {}}))
            with self.assertRaisesRegex(ul.UpdateError, "schema_version"):
                default_call(leaderboard_dir=lb, passed=["x"])

    def test_invalid_benchmark_sha_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            with self.assertRaisesRegex(ul.UpdateError, "40-char hex SHA"):
                default_call(leaderboard_dir=lb, passed=["x"], benchmark_commit="notasha")

    def test_invalid_login_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            with self.assertRaisesRegex(ul.UpdateError, "GitHub login"):
                default_call(leaderboard_dir=lb, passed=["x"], user="not a login")

    def test_empty_passed_list_is_noop(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            result = default_call(leaderboard_dir=lb, passed=[])
            self.assertFalse(result["changed"])
            self.assertEqual(result["added"], [])
            self.assertFalse((lb / "results" / "alice.json").exists())

    def test_production_description_recorded_when_supplied(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            default_call(
                leaderboard_dir=lb,
                passed=["x"],
                production_description="Custom orchestrator + Claude Opus 4.7.",
            )
            record = json.loads((lb / "results" / "alice.json").read_text())["solved"]["x"]
            self.assertEqual(
                record["production_description"],
                "Custom orchestrator + Claude Opus 4.7.",
            )

    def test_production_description_sticky_no_op(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            default_call(
                leaderboard_dir=lb,
                passed=["x"],
                production_description="first description",
            )
            # Re-submitting the same problem with a different description must
            # not overwrite the existing record (sticky-no-op semantics).
            default_call(
                leaderboard_dir=lb,
                passed=["x"],
                production_description="second description",
            )
            record = json.loads((lb / "results" / "alice.json").read_text())["solved"]["x"]
            self.assertEqual(record["production_description"], "first description")

    def test_production_description_oversize_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            oversize = "x" * (ul.PRODUCTION_DESCRIPTION_MAX_LEN + 1)
            with self.assertRaisesRegex(ul.UpdateError, "at most"):
                default_call(
                    leaderboard_dir=lb,
                    passed=["x"],
                    production_description=oversize,
                )

    def test_production_description_nul_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            with self.assertRaisesRegex(ul.UpdateError, "NUL"):
                default_call(
                    leaderboard_dir=lb,
                    passed=["x"],
                    production_description="bad\x00string",
                )

    def test_production_description_blank_treated_as_absent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp)
            default_call(
                leaderboard_dir=lb,
                passed=["x"],
                production_description="   \n\t  ",
            )
            record = json.loads((lb / "results" / "alice.json").read_text())["solved"]["x"]
            self.assertNotIn("production_description", record)

    def test_cli_end_to_end_writes_and_prints_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            lb = pathlib.Path(tmp) / "lb"
            lb.mkdir()
            results_path = pathlib.Path(tmp) / "results.json"
            results_path.write_text(json.dumps({"passed": ["two_plus_two"]}))
            import io
            import contextlib
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = ul.main([
                    "--user", "alice",
                    "--leaderboard-dir", str(lb),
                    "--results-json", str(results_path),
                    "--benchmark-commit", BENCHMARK_COMMIT,
                    "--submission-repo", "alice/proofs",
                    "--submission-ref", SUBMISSION_REF,
                    "--submission-public",
                    "--model", "Claude Opus 4.6",
                    "--issue-number", "42",
                    "--now", "2026-04-11T10:45:00Z",
                ])
            self.assertEqual(rc, 0)
            payload = json.loads(buf.getvalue())
            self.assertTrue(payload["changed"])
            self.assertEqual(payload["added"], ["two_plus_two"])
            self.assertTrue((lb / "results" / "alice.json").is_file())


if __name__ == "__main__":
    unittest.main()
