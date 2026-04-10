from __future__ import annotations

import pathlib
import sys
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import validate_submission as vs  # noqa: E402


class ValidateSubmissionTests(unittest.TestCase):
    def test_explicit_submission_paths_are_treated_as_modifications(self) -> None:
        changes = vs.parse_explicit_file_changes(
            [
                "generated/two_plus_two/Submission.lean",
                "generated/two_plus_two/Submission/Helpers.lean",
            ]
        )
        self.assertEqual(
            changes,
            [
                vs.SubmissionChange(status="M", paths=("generated/two_plus_two/Submission.lean",)),
                vs.SubmissionChange(
                    status="M", paths=("generated/two_plus_two/Submission/Helpers.lean",)
                ),
            ],
        )

    def test_top_level_submission_files_only_allow_modifications(self) -> None:
        allowed, forbidden = vs.validate_changed_files(
            [vs.SubmissionChange(status="D", paths=("generated/two_plus_two/Solution.lean",))]
        )
        self.assertEqual(allowed, [])
        self.assertEqual(len(forbidden), 1)
        self.assertIn("top-level submission files only allow statuses", forbidden[0]["reasons"][0])

    def test_submission_helpers_allow_rename_within_submission_tree(self) -> None:
        allowed, forbidden = vs.validate_changed_files(
            [
                vs.SubmissionChange(
                    status="R100",
                    paths=(
                        "generated/two_plus_two/Submission/Helpers.lean",
                        "generated/two_plus_two/Submission/ExtraHelpers.lean",
                    ),
                )
            ]
        )
        self.assertEqual(forbidden, [])
        self.assertEqual(
            allowed,
            [
                vs.SubmissionChange(
                    status="R100",
                    paths=(
                        "generated/two_plus_two/Submission/Helpers.lean",
                        "generated/two_plus_two/Submission/ExtraHelpers.lean",
                    ),
                )
            ],
        )

    def test_rename_into_forbidden_path_is_rejected(self) -> None:
        allowed, forbidden = vs.validate_changed_files(
            [
                vs.SubmissionChange(
                    status="R100",
                    paths=(
                        "generated/two_plus_two/Submission/Helpers.lean",
                        "generated/two_plus_two/Challenge.lean",
                    ),
                )
            ]
        )
        self.assertEqual(allowed, [])
        self.assertEqual(len(forbidden), 1)
        self.assertIn("outside the submission whitelist", "\n".join(forbidden[0]["reasons"]))

    def test_unknown_problem_path_is_rejected(self) -> None:
        allowed, forbidden = vs.validate_changed_files(
            [vs.SubmissionChange(status="M", paths=("generated/not_a_problem/Submission.lean",))]
        )
        self.assertEqual(allowed, [])
        self.assertEqual(len(forbidden), 1)
        self.assertIn("known generated problem workspace", forbidden[0]["reasons"][0])

    def test_non_lean_submission_file_is_rejected(self) -> None:
        allowed, forbidden = vs.validate_changed_files(
            [vs.SubmissionChange(status="A", paths=("generated/two_plus_two/Submission/data.json",))]
        )
        self.assertEqual(allowed, [])
        self.assertEqual(len(forbidden), 1)
        self.assertIn("outside the submission whitelist", forbidden[0]["reasons"][0])

    def test_absolute_and_traversal_paths_are_rejected(self) -> None:
        with self.assertRaisesRegex(vs.gp.GenerationError, "relative to the repo root"):
            vs.normalize_submission_path("/tmp/Submission.lean")
        with self.assertRaisesRegex(vs.gp.GenerationError, "clean relative repo path"):
            vs.normalize_submission_path("../generated/two_plus_two/Submission.lean")

    def test_name_status_parser_handles_rename_records(self) -> None:
        changes = vs.parse_name_status_output(
            (
                "M\0generated/two_plus_two/Submission.lean\0"
                "R100\0generated/two_plus_two/Submission/Helpers.lean\0"
                "generated/two_plus_two/Submission/ExtraHelpers.lean\0"
            ).encode("utf-8")
        )
        self.assertEqual(
            changes,
            [
                vs.SubmissionChange(status="M", paths=("generated/two_plus_two/Submission.lean",)),
                vs.SubmissionChange(
                    status="R100",
                    paths=(
                        "generated/two_plus_two/Submission/Helpers.lean",
                        "generated/two_plus_two/Submission/ExtraHelpers.lean",
                    ),
                ),
            ],
        )


if __name__ == "__main__":
    unittest.main()
