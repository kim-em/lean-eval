from __future__ import annotations

import json
import os
import pathlib
import resource
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest
import tomllib


ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/fetch_dependency_caches.sh"


class FetchDependencyCachesTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = pathlib.Path(directory.name)
        self.project = self.root / "project with spaces"
        package = self.project / ".lake/packages/TauCeti"
        package.mkdir(parents=True)
        manifest = {"packages": [{"name": "TauCeti", "rev": "1" * 40},
                                 {"name": "mathlib", "rev": "2" * 40}]}
        for path in [self.project, package]:
            (path / "lake-manifest.json").write_text(json.dumps(manifest))
            (path / "lean-toolchain").write_text((ROOT / "lean-toolchain").read_text())
        (self.project / "Main.lean").write_text("import TauCeti.Example\n")
        (package / "TauCeti").mkdir()
        (package / "TauCeti/Example.lean").write_text("def example := 1\n")
        self.calls = self.root / "calls.jsonl"
        tools = self.root / "bin"
        tools.mkdir()
        (tools / "lake").write_text(
            f"#!{sys.executable}\n"
            "import json,os,sys,pathlib,resource\n"
            f"calls=pathlib.Path({str(self.calls)!r})\n"
            "previous=calls.read_text().splitlines() if calls.exists() else []\n"
            "with calls.open('a') as f: f.write(json.dumps({'args':sys.argv[1:],"
            "'stack':resource.getrlimit(resource.RLIMIT_STACK)[0],"
            "'curl':os.environ.get('CURL'), 'config':pathlib.Path(os.environ['LAKE_CONFIG']).read_text()})+'\\n')\n"
            "if 'build' in sys.argv:\n"
            " count=sum('build' in json.loads(p)['args'] for p in previous)\n"
            " if count < int(os.environ.get('FAIL_RESTORES','0')):\n"
            "  print('curl: (22) artifact service returned 503')\n"
            "  sys.exit(3)\n"
            " print(os.environ.get('BUILD_MESSAGE', 'Fetched TauCeti.Example'))\n"
        )
        (tools / "lake").chmod(0o755)
        (tools / "sleep").write_text("#!/bin/sh\nexit 0\n")
        (tools / "sleep").chmod(0o755)
        self.env = dict(os.environ, PATH=f"{tools}{os.pathsep}{os.environ['PATH']}",
                        GITHUB_ENV="", RUNNER_TEMP=str(self.root))

    def run_script(self, failures):
        # Include Lean's parser startup and the deliberately exercised retry
        # backoff, including on small hosted runners or a busy development host.
        return subprocess.run(["bash", str(SCRIPT), "--restore", str(self.project)],
                              env=dict(self.env, FAIL_RESTORES=str(failures)),
                              capture_output=True, text=True, check=False, timeout=90)

    def test_retries_cache_only_restore_and_exports_wrapper_for_later_builds(self):
        result = self.run_script(1)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        restores = [c for c in calls if "build" in c["args"]]
        self.assertEqual(len(restores), 2)
        self.assertTrue(all("--no-build" in c["args"] for c in restores))
        wrapper = str(ROOT / "scripts/lake_cache_curl.py")
        self.assertTrue(all(c["curl"] == wrapper for c in calls))
        exports = dict(word.split("=", 1) for word in shlex.split(result.stdout)[1:])
        self.assertEqual(exports["CURL"], wrapper)
        self.assertEqual(exports["LAKE_ARTIFACT_CACHE"], "true")
        self.assertEqual(exports["LAKE_RESTORE_ARTIFACTS"], "true")
        self.assertIn("503", result.stderr)

    def test_exhausted_cache_only_restore_fails_without_exporting_settings(self):
        result = self.run_script(2)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("no compilation was permitted", result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual(sum("build" in c["args"] for c in calls), 2)

    def test_restore_inherits_enough_stack_for_deep_cached_proofs(self):
        def limited_stack():
            _, hard = resource.getrlimit(resource.RLIMIT_STACK)
            resource.setrlimit(resource.RLIMIT_STACK, (8 * 1024 * 1024, hard))

        result = subprocess.run(["bash", str(SCRIPT), "--restore", str(self.project)],
                                env=self.env, capture_output=True, text=True,
                                preexec_fn=limited_stack, timeout=90)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        restore = next(c for c in calls if "build" in c["args"])
        self.assertTrue(restore["stack"] == resource.RLIM_INFINITY or
                        restore["stack"] >= 64 * 1024 * 1024)

    def test_pin_mismatch_stops_before_any_lake_command(self):
        (self.project / "lean-toolchain").write_text("leanprover/lean4:v4.34.0\n")
        result = self.run_script(0)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Pin the same toolchain and Mathlib", result.stderr)
        self.assertFalse(self.calls.exists())


    def add_library(self, name, dependencies=None):
        path = self.project / ".lake/packages" / name
        path.mkdir(parents=True)
        root_manifest = json.loads((self.project / "lake-manifest.json").read_text())
        root_manifest["packages"].append({"name": name, "rev": "3" * 40})
        (self.project / "lake-manifest.json").write_text(json.dumps(root_manifest))
        (path / "lake-manifest.json").write_text(json.dumps({"packages": dependencies or [
            {"name": "mathlib", "rev": "2" * 40}]}))
        (path / "lean-toolchain").write_text((ROOT / "lean-toolchain").read_text())
        for module in {"cfsg": ["CFSG", "CFSG/Real", "CFSG/Example", "Certificates/Data/Example"],
                       "Stacks": ["Stacks", "StacksCore/Example", "StacksFrontier/Example"]}.get(name, []):
            source = path / (module + ".lean")
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text("def example := 1\n")
        return path

    def test_multiple_caches_and_transitive_tauceti_use_distinct_services(self):
        self.add_library("cfsg", [{"name": "mathlib", "rev": "2" * 40},
                                  {"name": "TauCeti", "rev": "1" * 40}])
        self.add_library("Stacks")
        self.env.update(STACKS_ARTIFACT_ENDPOINT="https://stacks.example/artifacts",
                        STACKS_REVISION_ENDPOINT="https://stacks.example/revisions")
        (self.project / "Main.lean").write_text(
            "module\n/- outer /- import CFSG.Fake -/ comment -/\n"
            "public import\n  CFSG.Real\nimport Certificates.Data.Example\n"
            "meta import all StacksCore.Example\nimport StacksFrontier.Example\n")
        result = self.run_script(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        mappings = [c for c in calls if "cache" in c["args"]]
        self.assertEqual({c["args"][c["args"].index("--package") + 1] for c in mappings},
                         {"cfsg", "Stacks", "TauCeti"})
        config = tomllib.loads(calls[0]["config"])
        self.assertEqual({s["name"] for s in config["cache"]["service"]},
                         {"cfsg-public", "stacks-public", "tauceti-public"})
        build = next(c["args"] for c in calls if "build" in c["args"])
        self.assertIn("+CFSG.Real", build)
        self.assertIn("+Certificates.Data.Example", build)
        self.assertIn("+StacksCore.Example", build)
        self.assertIn("+StacksFrontier.Example", build)
        self.assertNotIn("+CFSG.Fake", build)

    def test_unused_libraries_need_no_cache_or_matching_toolchain(self):
        stacks = self.add_library("Stacks")
        (stacks / "lean-toolchain").write_text("leanprover/lean4:v4.34.0\n")
        (self.project / "Main.lean").write_text("import Mathlib\n")
        result = self.run_script(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertFalse(self.calls.exists())

    def test_parsing_submission_headers_never_executes_solver_code(self):
        marker = self.root / "solver-code-ran"
        (self.project / "Main.lean").write_text(
            f'import Lean\n#eval IO.FS.writeFile {json.dumps(str(marker))} "executed"\n')
        result = self.run_script(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(marker.exists())
        self.assertFalse(self.calls.exists())

    def test_bad_solver_imports_are_left_to_comparator_without_running_lake(self):
        for header in ["import TauCeti.\n", "import TauCeti.Missing\n",
                       "import TauCeti.«../../Submission/Evil»\n"]:
            with self.subTest(header=header):
                (self.project / "Main.lean").write_text(header)
                result = self.run_script(0)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.calls.exists())

    def test_transitive_pin_mismatch_is_rejected_before_fetching(self):
        self.add_library("cfsg", [{"name": "mathlib", "rev": "2" * 40},
                                  {"name": "TauCeti", "rev": "0" * 40}])
        (self.project / "Main.lean").write_text("import CFSG.Example\n")
        result = self.run_script(0)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Different dependency pins: TauCeti", result.stderr)
        self.assertFalse(self.calls.exists())

    def test_stacks_uses_published_endpoints_with_empty_workflow_overrides(self):
        self.add_library("Stacks")
        self.env.update(STACKS_ARTIFACT_ENDPOINT="", STACKS_REVISION_ENDPOINT="")
        (self.project / "Main.lean").write_text("import Stacks\n")
        result = self.run_script(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        service = tomllib.loads(calls[0]["config"])["cache"]["service"][0]
        self.assertEqual(service["artifactEndpoint"],
                         "https://stacks-cache.axiommath.workers.dev/lake/artifacts")
        self.assertEqual(service["revisionEndpoint"],
                         "https://stacks-cache.axiommath.workers.dev/lake/revisions")

    def test_missing_checkout_fails_before_fetching(self):
        self.add_library("Stacks")
        (self.project / ".lake/packages/Stacks/lake-manifest.json").unlink()
        (self.project / "Main.lean").write_text("import Stacks\n")
        result = self.run_script(0)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fetch the dependencies first", result.stderr)
        self.assertFalse(self.calls.exists())

    def test_github_environment_and_no_build_defense(self):
        environment = self.root / "github-env"
        self.env["GITHUB_ENV"] = str(environment)
        result = self.run_script(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertIn("LAKE_CONFIG=", environment.read_text())
        self.env["BUILD_MESSAGE"] = "Built TauCeti.Example"
        environment.unlink()
        result = self.run_script(0)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("compiled instead of downloaded", result.stderr)
        self.assertFalse(environment.exists())


class BenchmarkVariantScanTests(unittest.TestCase):
    """A benchmark root on a library variant ignores imports of the variant's unsupported problems."""

    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.project = pathlib.Path(directory.name)
        for name in ["supported-toolchains.json", "toolchains", "manifests/problems"]:
            (shutil.copytree if (ROOT / name).is_dir() else shutil.copy)(ROOT / name, self.project / name)
        self.registry = json.loads((ROOT / "supported-toolchains.json").read_text())
        for path in (ROOT / "manifests/problems").glob("*.toml"):
            module = tomllib.loads(path.read_text())["module"]
            if module in self.registry["variants"]["stacks"]["unsupported_modules"]:
                for source in [self.project.joinpath(*module.split(".")).with_suffix(".lean"),
                               self.project / "generated" / path.stem / "ChallengeDeps.lean"]:
                    source.parent.mkdir(parents=True, exist_ok=True)
                    source.write_text("import TauCeti.Example\n")

    def run_on(self, configuration):
        profile = self.registry["configurations"][self.registry.get(configuration, configuration)]
        for name in ["lean-toolchain", "lakefile.toml", "lake-manifest.json"]:
            shutil.copy(self.project / profile / name, self.project / name)
        return subprocess.run(["bash", str(SCRIPT), "--restore", str(self.project)],
                              env=dict(os.environ, GITHUB_ENV=""), capture_output=True,
                              text=True, check=False, timeout=90)

    def test_stacks_root_skips_unsupported_problem_imports(self):
        result = self.run_on("stacks")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nothing to fetch", result.stderr)

    def test_support_roles_still_scan_every_problem(self):
        result = self.run_on("previous-stable")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("TauCeti", result.stderr)


if __name__ == "__main__":
    unittest.main()
