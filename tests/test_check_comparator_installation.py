from __future__ import annotations

import pathlib
import subprocess
from unittest import mock
import sys
import tempfile
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import check_comparator_installation as comparator_check  # noqa: E402


class CheckComparatorInstallationTests(unittest.TestCase):
    def test_parse_semver(self) -> None:
        self.assertEqual(comparator_check.parse_semver("landrun version 0.1.15"), (0, 1, 15))
        self.assertEqual(comparator_check.parse_semver("v0.1.14"), (0, 1, 14))
        self.assertIsNone(comparator_check.parse_semver("no version here"))

    def test_missing_landrun_flags(self) -> None:
        help_text = "usage: landrun --best-effort --ro --rw --rox --rwx --ldd"
        self.assertEqual(comparator_check.missing_landrun_flags(help_text), ["--add-exec"])

    def test_landrun_install_advice_points_to_pinned_sha(self) -> None:
        advice = comparator_check.landrun_install_advice()
        target = comparator_check.LANDRUN_INSTALL_TARGET
        # Pin must be a 40-char hex SHA (no branches, no tags) so the
        # bump procedure is auditable and CI cannot drift silently.
        self.assertRegex(target, r"^[0-9a-f]{40}$")
        self.assertIn(f"@{target}", advice)

    def test_validate_landrun_rejects_missing_flags(self) -> None:
        inspection = comparator_check.LandrunInspection(
            path="/tmp/landrun",
            help_text="usage: landrun --best-effort --ro --rw",
            version_text="landrun version 0.1.15",
            version=(0, 1, 15),
        )
        with self.assertRaisesRegex(RuntimeError, "missing comparator-required flags"):
            comparator_check.validate_landrun(inspection)

    def test_validate_landrun_rejects_old_versions(self) -> None:
        inspection = comparator_check.LandrunInspection(
            path="/tmp/landrun",
            help_text=" ".join(comparator_check.REQUIRED_LANDRUN_FLAGS),
            version_text="landrun version 0.1.13",
            version=(0, 1, 13),
        )
        with self.assertRaisesRegex(RuntimeError, "too old"):
            comparator_check.validate_landrun(inspection)

    def test_probe_landrun_with_lean_toolchain_reports_dynamic_exec_failure(self) -> None:
        with mock.patch.object(
            comparator_check.shutil,
            "which",
            side_effect=lambda name: "/mock/lean" if name == "lean" else None,
        ), mock.patch.object(comparator_check, "run_capture") as run_capture:
            run_capture.side_effect = [
                subprocess.CompletedProcess(
                    ["/mock/lean", "--print-prefix"], 0, stdout="/mock/toolchain\n", stderr=""
                ),
                subprocess.CompletedProcess(
                    ["landrun"], 1, stdout="", stderr="[landrun:error] permission denied"
                ),
            ]
            with mock.patch.object(
                comparator_check.pathlib.Path, "is_file", return_value=True
            ):
                with self.assertRaisesRegex(RuntimeError, "Lean toolchain execution probe"):
                    comparator_check.probe_landrun_with_lean_toolchain("/mock/landrun")

    def test_solve_two_plus_two_replaces_placeholder(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            workspace = pathlib.Path(tmpdir)
            submission = workspace / "Submission.lean"
            submission.write_text(
                "namespace Submission\n\n"
                "theorem two_plus_two_eq_four : (2 : Nat) + 2 = 4 := by\n"
                "  sorry\n\n"
                "end Submission\n",
                encoding="utf-8",
            )
            comparator_check.solve_two_plus_two(workspace)
            content = submission.read_text(encoding="utf-8")
            self.assertIn("  norm_num\n", content)
            self.assertNotIn("  sorry\n", content)


if __name__ == "__main__":
    unittest.main()
