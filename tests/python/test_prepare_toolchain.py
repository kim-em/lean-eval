from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("prepare_toolchain", ROOT / "scripts/prepare_toolchain.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PrepareToolchainTests(unittest.TestCase):
    def test_published_configurations_have_matching_dependency_pins(self):
        default, profiles = MODULE.configurations(ROOT)
        self.assertEqual(default, "latest")
        self.assertEqual(set(profiles), {"leanprover/lean4:v4.36.0", "leanprover/lean4:v4.35.0", "latest"})
        registry = json.loads((ROOT / "supported-toolchains.json").read_text())
        self.assertEqual(registry["rc"], registry["stable"])
        self.assertEqual(registry["previous-stable"], "leanprover/lean4:v4.35.0")
        for name in MODULE.FILES:
            self.assertEqual((profiles["latest"] / name).read_bytes(),
                             (profiles[registry["stable"]] / name).read_bytes())
            self.assertEqual((profiles[default] / name).read_bytes(), (ROOT / name).read_bytes())
        for profile in profiles.values():
            lakefile = tomllib.loads((profile / "lakefile.toml").read_text())
            packages = {p["name"].strip("«»"): p for p in json.loads(
                (profile / "lake-manifest.json").read_text())["packages"]}
            for dependency in lakefile["require"]:
                self.assertEqual(dependency["rev"], packages[dependency["name"]]["rev"])

    def fixture(self, root):
        for relative, pin in [(".", "leanprover/lean4:v4.36.0-rc2"),
                              ("stable", "leanprover/lean4:v4.35.0")]:
            profile = root / relative
            profile.mkdir(exist_ok=True)
            (profile / "lean-toolchain").write_text(pin + "\n")
            (profile / "lakefile.toml").write_text(relative)
            (profile / "lake-manifest.json").write_text(relative)
        (root / "supported-toolchains.json").write_text(json.dumps({
            "default": "leanprover/lean4:v4.36.0-rc2", "stable": "leanprover/lean4:v4.35.0",
            "configurations": {
                "leanprover/lean4:v4.36.0-rc2": ".", "leanprover/lean4:v4.35.0": "stable"}}))

    def test_isolated_copy_selects_stable_and_excludes_build_state(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "benchmark"
            root.mkdir()
            self.fixture(root)
            (root / ".lake").mkdir()
            (root / ".lake/secret-cache").write_text("old artifacts")
            destination = root / ".lake/stable-copy"
            MODULE.prepare(root, "stable", destination)
            self.assertEqual((destination / "lakefile.toml").read_text(), "stable")
            self.assertFalse((destination / ".lake").exists())
            self.assertEqual((root / "lakefile.toml").read_text(), ".")
            with self.assertRaisesRegex(ValueError, "already exists"):
                MODULE.prepare(root, "stable", destination)
            with self.assertRaisesRegex(ValueError, "fresh checkout"):
                MODULE.prepare(root, "stable")

    def test_unsupported_toolchains_and_escaping_configurations_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.fixture(root)
            with self.assertRaisesRegex(ValueError, "unsupported"):
                MODULE.prepare(root, "leanprover/lean4:nightly")
            registry = root / "supported-toolchains.json"
            value = json.loads(registry.read_text())
            value["configurations"][value["default"]] = "../outside"
            registry.write_text(json.dumps(value))
            with self.assertRaisesRegex(ValueError, "escapes"):
                MODULE.prepare(root, "stable")

    def test_previous_stable_alias_selects_its_own_snapshot(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "benchmark"
            root.mkdir()
            self.fixture(root)
            path = root / "supported-toolchains.json"
            registry = json.loads(path.read_text())
            registry["previous-stable"] = registry["stable"]
            path.write_text(json.dumps(registry))
            destination = Path(temporary) / "previous-stable"
            MODULE.prepare(root, "previous-stable", destination)
            self.assertEqual((destination / "lakefile.toml").read_text(), "stable")
            registry["previous-stable"] = "missing"
            path.write_text(json.dumps(registry))
            with self.assertRaisesRegex(ValueError, "alias has no configuration"):
                MODULE.configurations(root)


if __name__ == "__main__":
    unittest.main()
