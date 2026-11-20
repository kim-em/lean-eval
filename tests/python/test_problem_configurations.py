from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import problem_configurations as policy


class ProblemConfigurationsTests(unittest.TestCase):
    def test_only_nested_support_levels_are_accepted(self):
        self.assertEqual(policy.supported_configurations({}), ("latest", "rc", "stable", "previous-stable"))
        for value in [["latest"], ["latest", "rc"], ["stable", "latest", "rc"],
                      ["previous-stable", "stable", "latest", "rc"]]:
            self.assertEqual(set(policy.supported_configurations({"supported_configurations": value})), set(value))
        for value in [[], ["rc"], ["latest", "stable"], ["latest", "previous-stable"],
                      ["latest", "latest"], ["nightly"], "latest", [False]]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                policy.supported_configurations({"supported_configurations": value})

    def write_problem(self, root, name, supported=None):
        directory = root / "manifests/problems"
        directory.mkdir(parents=True, exist_ok=True)
        content = f'id = "{name}"\nmodule = "LeanEval.{name.upper()}"\n'
        if supported is not None:
            content += f'supported_configurations = {json.dumps(supported)}\n'
        (directory / f"{name}.toml").write_text(content)

    def test_module_selection_respects_problem_coverage(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_problem(root, "a", ["latest"])
            self.write_problem(root, "b", ["latest", "rc"])
            self.write_problem(root, "c", ["latest", "rc", "stable"])
            self.write_problem(root, "d")
            for configuration, expected in [("latest", ["LeanEval.A", "LeanEval.B", "LeanEval.C", "LeanEval.D"]),
                                            ("rc", ["LeanEval.B", "LeanEval.C", "LeanEval.D"]),
                                            ("stable", ["LeanEval.C", "LeanEval.D"]),
                                            ("previous-stable", ["LeanEval.D"])]:
                self.assertEqual(policy.compatible_modules(root, configuration, []), expected)
            self.assertEqual(policy.compatible_modules(root, "stable", ["LeanEval.A"]), [])
            with self.assertRaisesRegex(ValueError, "unknown problem modules"):
                policy.compatible_modules(root, "stable", ["LeanEval.Typo"])
            with self.assertRaisesRegex(ValueError, "does not support stable"):
                policy.require_supported(root, "stable", ["b"])
            with self.assertRaisesRegex(ValueError, "does not support previous-stable"):
                policy.require_supported(root, "previous-stable", ["c"])

    def test_upgrades_cannot_narrow_or_delete_existing_problem_support(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_problem(root, "a")
            self.write_problem(root, "b", ["latest"])
            for args in [["init", "-q"], ["add", "."],
                         ["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base"]]:
                subprocess.run(["git", *args], cwd=root, check=True)
            self.write_problem(root, "b", ["latest", "rc"])
            self.write_problem(root, "new", ["latest"])
            policy.check_no_regressions(root, "HEAD")
            self.write_problem(root, "a", ["latest", "rc"])
            with self.assertRaisesRegex(ValueError, "compatibility would decrease for previous-stable, stable"):
                policy.check_no_regressions(root, "HEAD")
            self.write_problem(root, "a")
            (root / "manifests/problems/a.toml").unlink()
            with self.assertRaisesRegex(ValueError, "removing a problem"):
                policy.check_no_regressions(root, "HEAD")

    def test_checkout_configuration_uses_full_dependency_pins(self):
        self.assertEqual(policy.current_configuration(ROOT), "latest")

    def test_library_variant_inherits_role_without_narrowing_the_canonical_snapshot(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_problem(root, "a")
            self.write_problem(root, "b", ["latest"])
            self.write_problem(root, "c")
            profiles = {"latest": ("v4.36.0", "current"),
                        "previous": ("v4.35.0", "tauceti"), "stacks": ("v4.35.0", "stacks")}
            for directory, (lean, snapshot) in profiles.items():
                profile = root / directory
                profile.mkdir()
                (profile / "lean-toolchain").write_text("leanprover/lean4:" + lean)
                (profile / "lakefile.toml").write_text(snapshot)
                (profile / "lake-manifest.json").write_text(snapshot)
            registry = {"default": "latest", "latest": "latest",
                        "stable": "leanprover/lean4:v4.36.0", "rc": "leanprover/lean4:v4.36.0",
                        "previous-stable": "leanprover/lean4:v4.35.0",
                        "configurations": {"latest": "latest", "leanprover/lean4:v4.36.0": "latest",
                                           "leanprover/lean4:v4.35.0": "previous", "stacks": "stacks"},
                        "variants": {"stacks": {"support_role": "previous-stable",
                                                "unsupported_modules": ["LeanEval.C"]}}}
            (root / "supported-toolchains.json").write_text(json.dumps(registry))
            for name in ("lean-toolchain", "lakefile.toml", "lake-manifest.json"):
                (root / name).write_bytes((root / "stacks" / name).read_bytes())
            self.assertEqual(policy.current_configuration(root), "stacks")
            self.assertEqual(policy.configuration_alias(root, "stacks"), "stacks")
            self.assertEqual(policy.compatible_modules(root, "stacks", []), ["LeanEval.A"])
            self.assertEqual(policy.compatible_modules(root, "previous-stable", []), ["LeanEval.A", "LeanEval.C"])
            policy.require_supported(root, "previous-stable", ["c"])
            policy.require_supported(root, "stacks", ["a"])
            with self.assertRaisesRegex(ValueError, "unavailable in stacks; choose previous-stable"):
                policy.require_supported(root, "stacks", ["c"])
            with self.assertRaisesRegex(ValueError, "does not support stacks"):
                policy.require_supported(root, "stacks", ["b"])
            registry["variants"]["stacks"]["unsupported_modules"] = ["LeanEval.Typo"]
            (root / "supported-toolchains.json").write_text(json.dumps(registry))
            with self.assertRaisesRegex(ValueError, "unknown unsupported modules"):
                policy.compatible_modules(root, "stacks", [])

    def test_retained_variant_cannot_lose_compatible_problems(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_problem(root, "a")
            self.write_problem(root, "b")
            registry = {"variants": {"stacks": {"support_role": "previous-stable",
                                                "unsupported_modules": ["LeanEval.B"]}}}
            path = root / "supported-toolchains.json"
            path.write_text(json.dumps(registry))
            for args in [["init", "-q"], ["add", "."],
                         ["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base"]]:
                subprocess.run(["git", *args], cwd=root, check=True)
            registry["variants"]["stacks"]["unsupported_modules"] = []
            path.write_text(json.dumps(registry))
            policy.check_no_regressions(root, "HEAD")
            registry["variants"]["stacks"]["unsupported_modules"] = ["LeanEval.A", "LeanEval.B"]
            path.write_text(json.dumps(registry))
            with self.assertRaisesRegex(ValueError, "compatibility would decrease for stacks"):
                policy.check_no_regressions(root, "HEAD")


if __name__ == "__main__":
    unittest.main()
