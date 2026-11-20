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


if __name__ == "__main__":
    unittest.main()
