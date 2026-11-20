from __future__ import annotations

import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
SPEC = importlib.util.spec_from_file_location("select_submission_toolchain",
                                            ROOT / "scripts/select_submission_toolchain.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class SelectSubmissionToolchainTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / "manifests/problems").mkdir(parents=True)
        for problem in ("a", "b"):
            (self.root / f"manifests/problems/{problem}.toml").write_text("")
            (self.root / f"generated/{problem}").mkdir(parents=True)
            (self.root / f"generated/{problem}/Submission.lean").write_text("-- stub\n")
        for relative, pin in [("rc", "v4.36.0-rc2"), ("stable", "v4.35.0")]:
            profile = self.root / relative
            profile.mkdir()
            for name in ["lean-toolchain", "lakefile.toml", "lake-manifest.json"]:
                (profile / name).write_text("leanprover/lean4:" + pin if name == "lean-toolchain" else "{}")
        (self.root / "supported-toolchains.json").write_text(json.dumps({
            "default": "leanprover/lean4:v4.36.0-rc2", "stable": "leanprover/lean4:v4.35.0",
            "configurations": {
                "leanprover/lean4:v4.36.0-rc2": "rc", "leanprover/lean4:v4.35.0": "stable"}}))

    def archive(self, files):
        archive = self.root / "source.tar.gz"
        with tarfile.open(archive, "w:gz") as output:
            for name, value in files:
                member = tarfile.TarInfo(name)
                if value is None:
                    member.type = tarfile.SYMTYPE
                    member.linkname = "/etc/passwd"
                    output.addfile(member)
                else:
                    data = value.encode()
                    member.size = len(data)
                    output.addfile(member, io.BytesIO(data))
        return archive

    def workspace(self, problem="a", prefix="source/generated/a"):
        return [(prefix + "/lakefile.toml", f'name = "{problem}"'),
                (prefix + "/Submission.lean", "-- proof\n")]

    def test_root_pin_and_nearest_workspace_pin_select_approved_configurations(self):
        files = [("source/lean-toolchain", "leanprover/lean4:v4.35.0")] + self.workspace()
        selected, problems = MODULE.select(self.archive(files), self.root)
        self.assertEqual(selected, "leanprover/lean4:v4.35.0")
        self.assertEqual(problems, ["a"])
        files.append(("source/generated/a/lean-toolchain", "leanprover/lean4:v4.36.0-rc2"))
        self.assertEqual(MODULE.select(self.archive(files), self.root)[0],
                         "leanprover/lean4:v4.36.0-rc2")

    def test_pristine_workspaces_and_other_selected_problems_do_not_choose_toolchains(self):
        files = self.workspace() + [("source/generated/a/lean-toolchain", "leanprover/lean4:v4.35.0")]
        files += self.workspace("b", "source/generated/b")
        files += [("source/generated/b/lean-toolchain", "leanprover/lean4:v4.36.0-rc2")]
        archive = self.archive(files)
        with self.assertRaisesRegex(ValueError, "one toolchain"):
            MODULE.select(archive, self.root)
        self.assertEqual(MODULE.select(archive, self.root, "a")[0], "leanprover/lean4:v4.35.0")
        files = [(path, "-- stub\n" if path == "source/generated/b/Submission.lean" else content)
                 for path, content in files]
        self.assertEqual(MODULE.select(self.archive(files), self.root)[1], ["a"])

    def test_an_implicit_and_explicit_default_are_the_same_configuration(self):
        files = self.workspace() + self.workspace("a", "source/another-a")
        files.append(("source/another-a/lean-toolchain", "leanprover/lean4:v4.36.0-rc2"))
        self.assertEqual(MODULE.select(self.archive(files), self.root),
                         ("leanprover/lean4:v4.36.0-rc2", ["a"]))

    def latest_configuration(self):
        registry = self.root / "supported-toolchains.json"
        data = json.loads(registry.read_text())
        data["configurations"]["latest"] = "latest"
        registry.write_text(json.dumps(data))
        profile = self.root / "latest"
        profile.mkdir()
        (profile / "lean-toolchain").write_text("leanprover/lean4:v4.36.0-rc2\n")
        (profile / "lake-manifest.json").write_text("{}")
        for relative, revision in [("rc", "release"), ("latest", "newer")]:
            (self.root / relative / "lakefile.toml").write_text(
                f'[[require]]\nname = "mathlib"\nrev = "{revision}"\n')

    def pinned_workspace(self, revision, problem="a", prefix="source/generated/a"):
        return [(prefix + "/lakefile.toml",
                 f'name = "{problem}"\n[[require]]\nname = "mathlib"\nrev = "{revision}"\n'),
                (prefix + "/Submission.lean", "-- proof\n")]

    def test_dependency_pins_distinguish_configurations_sharing_lean(self):
        self.latest_configuration()
        for revision, expected in [("release", "leanprover/lean4:v4.36.0-rc2"),
                                   ("newer", "latest")]:
            with self.subTest(revision=revision):
                files = self.pinned_workspace(revision)
                self.assertEqual(MODULE.select(self.archive(files), self.root), (expected, ["a"]))
        with self.assertRaisesRegex(MODULE.ToolchainRequestError, "unsupported Mathlib/TauCeti"):
            MODULE.select(self.archive(self.pinned_workspace("unapproved")), self.root)

    def test_mixed_dependency_configurations_are_rejected_even_with_the_same_lean(self):
        self.latest_configuration()
        files = self.pinned_workspace("release") + self.pinned_workspace(
            "newer", "b", "source/generated/b")
        with self.assertRaisesRegex(MODULE.ToolchainRequestError, "one toolchain and dependency"):
            MODULE.select(self.archive(files), self.root)

    def test_coincident_profiles_select_latest_including_latest_only_problems(self):
        self.latest_configuration()
        registry = self.root / "supported-toolchains.json"
        data = json.loads(registry.read_text())
        stable = data["stable"]
        retired = data["default"]
        del data["configurations"][retired]
        data.update(default="latest", latest="latest", rc=stable)
        registry.write_text(json.dumps(data))
        (self.root / "stable/lakefile.toml").write_text(
            '[[require]]\nname = "mathlib"\nrev = "stable-mathlib"\n')
        for name in ("lean-toolchain", "lakefile.toml", "lake-manifest.json"):
            shutil.copyfile(self.root / "stable" / name, self.root / "latest" / name)
        (self.root / "manifests/problems/a.toml").write_text('supported_configurations = ["latest"]\n')
        for pin in (None, stable):
            with self.subTest(pin=pin):
                files = self.pinned_workspace("stable-mathlib")
                if pin is not None:
                    files.append(("source/lean-toolchain", pin))
                self.assertEqual(MODULE.select(self.archive(files), self.root), ("latest", ["a"]))
        files = self.workspace() + [("source/lean-toolchain", retired)]
        with self.assertRaisesRegex(MODULE.ToolchainRequestError, "unsupported requested toolchain"):
            MODULE.select(self.archive(files), self.root)

    def test_tauceti_pins_can_distinguish_snapshots_with_the_same_mathlib(self):
        self.latest_configuration()
        for relative, revision in [("rc", "older-tauceti"), ("latest", "newer-tauceti")]:
            (self.root / relative / "lakefile.toml").write_text(
                '[[require]]\nname = "mathlib"\nrev = "shared-mathlib"\n'
                f'[[require]]\nname = "TauCeti"\nrev = "{revision}"\n')
        files = self.pinned_workspace("shared-mathlib")
        files[0] = (files[0][0], files[0][1] +
                    '[[require]]\nname = "TauCeti"\nrev = "newer-tauceti"\n')
        self.assertEqual(MODULE.select(self.archive(files), self.root), ("latest", ["a"]))

    def test_missing_or_duplicate_library_pins_are_rejected(self):
        self.latest_configuration()
        for requirement in ['[[require]]\nname = "mathlib"\n',
                            '[[require]]\nname = "mathlib"\nrev = "release"\n' * 2]:
            files = self.workspace()
            files[0] = (files[0][0], files[0][1] + "\n" + requirement)
            with self.subTest(requirement=requirement), self.assertRaisesRegex(
                    MODULE.ToolchainRequestError, "one exact dependency pin"):
                MODULE.select(self.archive(files), self.root)

    def test_problem_support_is_enforced_before_evaluation(self):
        self.latest_configuration()
        (self.root / "manifests/problems/a.toml").write_text('supported_configurations = ["latest"]\n')
        with self.assertRaisesRegex(MODULE.ToolchainRequestError, "does not support rc"):
            MODULE.select(self.archive(self.pinned_workspace("release")), self.root)
        self.assertEqual(MODULE.select(self.archive(self.pinned_workspace("newer")), self.root),
                         ("latest", ["a"]))

    def test_previous_stable_is_allowed_only_for_problems_declaring_support(self):
        path = self.root / "supported-toolchains.json"
        data = json.loads(path.read_text())
        previous_stable = data["stable"]
        data.update(stable=data["default"], rc=data["default"])
        data["previous-stable"] = previous_stable
        path.write_text(json.dumps(data))
        files = self.workspace() + [("source/lean-toolchain", previous_stable)]
        self.assertEqual(MODULE.select(self.archive(files), self.root), (previous_stable, ["a"]))
        (self.root / "manifests/problems/a.toml").write_text(
            'supported_configurations = ["latest", "rc", "stable"]\n')
        with self.assertRaisesRegex(MODULE.ToolchainRequestError, "does not support previous-stable"):
            MODULE.select(self.archive(files), self.root)

    def test_cli_applies_latest_pins_and_preserves_the_runner_toolchain_contract(self):
        self.latest_configuration()
        scripts = self.root / "scripts"
        scripts.mkdir()
        for name in ["prepare_toolchain.py", "select_submission_toolchain.py", "problem_configurations.py"]:
            shutil.copyfile(ROOT / "scripts" / name, scripts / name)
        archive = self.archive(self.pinned_workspace("newer"))
        command = [sys.executable, str(scripts / "select_submission_toolchain.py"),
                   "--source-tar", str(archive)]
        archived = subprocess.run([*command, "--archive"], capture_output=True, text=True)
        self.assertEqual(archived.returncode, 0, archived.stderr)
        self.assertEqual(archived.stdout.strip(), "leanprover/lean4:v4.36.0-rc2")
        for name in ["lean-toolchain", "lakefile.toml", "lake-manifest.json"]:
            shutil.copyfile(self.root / "rc" / name, self.root / name)
        stale = subprocess.run([*command, "--regenerate"], capture_output=True, text=True)
        self.assertNotEqual(stale.returncode, 0)
        self.assertIn("select the requested configuration", stale.stderr)
        applied = subprocess.run([*command, "--expected", archived.stdout.strip(), "--apply"],
                                 capture_output=True, text=True)
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertIn('rev = "newer"', (self.root / "lakefile.toml").read_text())

    def test_unsupported_pins_escaping_paths_symlinks_and_duplicates_fail_closed(self):
        cases = [self.workspace() + [("source/lean-toolchain", "leanprover/lean4:nightly")],
                 [("../lean-toolchain", "ignored")], self.workspace() + [("source/lean-toolchain", None)],
                 [("source/lean-toolchain", "a"), ("source/lean-toolchain", "b")],
                 self.workspace() + [("source/lean-toolchain", "a" * 257)]]
        for files in cases:
            with self.subTest(files=files), self.assertRaises(ValueError):
                MODULE.select(self.archive(files), self.root)

    def test_archive_retains_unsupported_requests_but_evaluation_rejects_them(self):
        scripts = self.root / "scripts"
        scripts.mkdir()
        for name in ["prepare_toolchain.py", "select_submission_toolchain.py", "problem_configurations.py"]:
            shutil.copyfile(ROOT / "scripts" / name, scripts / name)
        archive = self.archive(self.workspace() + [
            ("source/lean-toolchain", "leanprover/lean4:nightly")])
        command = [sys.executable, str(scripts / "select_submission_toolchain.py"),
                   "--source-tar", str(archive)]
        archived = subprocess.run([*command, "--archive"], capture_output=True, text=True)
        self.assertEqual(archived.returncode, 0, archived.stderr)
        self.assertEqual(archived.stdout.strip(), "leanprover/lean4:v4.36.0-rc2")
        evaluated = subprocess.run([*command, "--expected", archived.stdout.strip()],
                                   capture_output=True, text=True)
        self.assertNotEqual(evaluated.returncode, 0)
        self.assertIn("unsupported requested toolchain", evaluated.stderr)

    def test_parser_recursion_is_an_input_rejection_and_unused_symlinks_are_ignored(self):
        with mock.patch.object(MODULE, "source_requests", side_effect=RecursionError("nested TOML")):
            with self.assertRaises(MODULE.ToolchainRequestError):
                MODULE.select(self.root / "source.tar.gz", self.root)
        files = self.workspace() + [("source/lean-toolchain", "leanprover/lean4:v4.35.0"),
                                    ("source/vendor/lakefile.toml", None),
                                    ("source/vendor/lean-toolchain", None)]
        self.assertEqual(MODULE.select(self.archive(files), self.root)[0], "leanprover/lean4:v4.35.0")


if __name__ == "__main__":
    unittest.main()
