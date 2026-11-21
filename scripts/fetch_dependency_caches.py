#!/usr/bin/env python3
"""Restore published Lake artifacts for the large libraries a project imports."""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import resource
import shlex
import subprocess
import sys
import tempfile
import time


SCRIPTS = Path(__file__).resolve().parent


@dataclass(frozen=True)
class Library:
    package: str
    repo: str
    roots: tuple[str, ...]
    prefix: str
    endpoint: str = ""


LIBRARIES = (
    Library("TauCeti", "TauCetiProject/TauCeti", ("TauCeti",), "TAUCETI",
            "https://cache.taucetiproject.org"),
    Library("cfsg", "AxiomMath/CFSG", ("CFSG", "CFSGWithCertificates", "Certificates", "Comparator"),
            "CFSG", "https://cfsg-downloads.axiommath.workers.dev/lake"),
    Library("Stacks", "AxiomMath/Stacks", ("Stacks", "StacksCore", "StacksFrontier"),
            "STACKS", "https://stacks-cache.axiommath.workers.dev/lake"),
)


def manifest(path: Path) -> dict[str, dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return {p["name"].strip("«»"): p for p in data["packages"]}


def variant_exclusions(project: Path) -> tuple[Path, ...]:
    """Sources of problems the benchmark's configuration variant does not provide.

    A variant such as `stacks` cannot build its `unsupported_modules`; scanning their imports would
    demand caches the variant cannot use. Other projects and support roles scan everything.
    """
    if not (project / "supported-toolchains.json").is_file():
        return ()
    sys.path.insert(0, str(SCRIPTS))
    from problem_configurations import configuration_policy, current_configuration, load_problems
    sys.path.pop(0)
    try:
        _, unavailable = configuration_policy(project, current_configuration(project))
    except ValueError:
        return ()
    return tuple(path.resolve() for name, problem in load_problems(project).items()
                 if problem["module"] in unavailable
                 for path in (project.joinpath(*problem["module"].split(".")).with_suffix(".lean"),
                              project / "generated" / name))


def imported_modules(project: Path, excluded: tuple[Path, ...] = ()) -> dict[str, list[str]]:
    paths = []

    def unreadable(error: OSError) -> None:
        raise error

    for directory, subdirs, files in os.walk(project, onerror=unreadable):
        subdirs[:] = sorted(d for d in subdirs if d not in {".lake", ".git"})
        paths.extend(str(Path(directory) / f) for f in sorted(files) if f.endswith(".lean"))
    paths = [p for p in paths if not any(e == Path(p).resolve() or e in Path(p).resolve().parents
                                         for e in excluded)]
    with tempfile.TemporaryDirectory(prefix="lean-eval-imports-") as temporary:
        source_list = Path(temporary) / "paths.json"
        source_list.write_text(json.dumps(paths), encoding="utf-8")
        result = subprocess.run(
            ["lean", "-j2", "--run", str(SCRIPTS / "dependency_imports.lean"), str(source_list)],
            cwd=project, text=True, capture_output=True, check=False,
        )
    if result.returncode:
        raise RuntimeError(f"could not parse project imports:\n{result.stdout}{result.stderr}")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    return dict(json.loads(result.stdout))


def belongs(module: str, library: Library) -> bool:
    return any(module == root or module.startswith(root + ".") for root in library.roots)


def retry(command: list[str], project: Path, env: dict[str, str], attempts: int) -> str:
    for attempt in range(1, attempts + 1):
        # Buffer only the diagnostics, not downloaded artifacts. Keep stdout
        # reserved for the export line the shell caller evaluates.
        result = subprocess.run(command, cwd=project, env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
        if result.returncode == 0:
            return result.stdout
        print(result.stdout, file=sys.stderr, end="")
        if attempt < attempts:
            print(f"::notice::dependency cache operation failed (attempt {attempt} of {attempts}); retrying",
                  file=sys.stderr)
            time.sleep(5)
    raise RuntimeError("dependency cache restoration failed after bounded retries; no compilation "
                       "was permitted. Check the pins and published cache coverage.")


def prepare(project: Path, restore: bool) -> dict[str, str]:
    packages = manifest(project / "lake-manifest.json")
    available = [lib for lib in LIBRARIES if lib.package in packages]
    if not available:
        print("fetch_dependency_caches: no supported packages in the manifest; nothing to fetch",
              file=sys.stderr)
        return {}
    modules = imported_modules(project, variant_exclusions(project))
    for module, parts in list(modules.items()):
        library = next((lib for lib in available if belongs(module, lib)), None)
        if library is None:
            continue
        directory = project / ".lake/packages" / library.package
        # Invalid/missing solver imports belong to comparator's verdict, not
        # an infrastructure failure for every problem in the submission.
        # Restrict CLI targets as well: quoted components can contain path
        # separators or dots, which Lake's target parser treats differently.
        plain = module == ".".join(parts) and all(
            part and all(c.isalnum() or c in "_'" for c in part) for part in parts)
        source = directory.joinpath(*parts[:-1], parts[-1] + ".lean")
        if not plain or ((directory / "lake-manifest.json").is_file() and not source.is_file()):
            print(f"fetch_dependency_caches: leaving unresolved import {module} to comparator",
                  file=sys.stderr)
            del modules[module]
    needed = [lib for lib in available if any(belongs(m, lib) for m in modules)]
    # CFSG's artifacts depend on TauCeti, even if the submission does not import
    # TauCeti directly. Register every supported transitive cache as well.
    directories = {}
    index = 0
    while index < len(needed):
        library = needed[index]
        index += 1
        directory = project / ".lake/packages" / library.package
        if not (directory / "lake-manifest.json").is_file():
            raise RuntimeError(f"{directory} is not checked out; fetch the dependencies first")
        directories[library.package] = directory
        dependencies = manifest(directory / "lake-manifest.json")
        for other in available:
            if other.package in dependencies and other not in needed:
                needed.append(other)
    if not needed:
        print("fetch_dependency_caches: no supported library imports; nothing to fetch", file=sys.stderr)
        return {}

    toolchain = (project / "lean-toolchain").read_text().strip()
    services = []
    # Validate every library before fetching anything: a different transitive
    # pin changes build traces just as a different Mathlib pin does.
    for library in needed:
        directory = directories[library.package]
        their_toolchain = (directory / "lean-toolchain").read_text().strip()
        dependencies = manifest(directory / "lake-manifest.json")
        mismatches = [name for name, dep in dependencies.items()
                      if name not in packages or packages[name].get("rev") != dep.get("rev")]
        if toolchain != their_toolchain or mismatches:
            raise RuntimeError(
                f"{library.package} {packages[library.package]['rev']} was built with {their_toolchain}; "
                f"this project pins {toolchain}. Different dependency pins: {', '.join(mismatches) or 'none'}. "
                "Pin the same toolchain and Mathlib (and other transitive dependencies) as the library "
                "commit so its build cache applies.")
        artifacts = (os.environ.get(f"{library.prefix}_ARTIFACT_ENDPOINT") or
                     (f"{library.endpoint}/artifacts" if library.endpoint else ""))
        revisions = (os.environ.get(f"{library.prefix}_REVISION_ENDPOINT") or
                     (f"{library.endpoint}/revisions" if library.endpoint else ""))
        if not artifacts or not revisions:
            raise RuntimeError(f"set {library.prefix}_ARTIFACT_ENDPOINT and "
                               f"{library.prefix}_REVISION_ENDPOINT to the publisher's public cache URLs")
        services.append((library, artifacts, revisions))

    descriptor, config_name = tempfile.mkstemp(
        prefix="lean-eval-dependency-cache.", dir=os.environ.get("RUNNER_TEMP") or None)
    config = Path(config_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            for library, artifacts, revisions in services:
                # JSON strings are valid TOML basic strings. Each fetched
                # mapping records its service, so multiple caches coexist.
                output.write('[[cache.service]]\n')
                output.write(f'name = "{library.prefix.lower()}-public"\nkind = "s3"\n')
                output.write(f"artifactEndpoint = {json.dumps(artifacts)}\n")
                output.write(f"revisionEndpoint = {json.dumps(revisions)}\n")
        # Runtime importModules consumers (the extractor and inventory tools)
        # need canonical .olean paths, even when subsequent builds hit a warm
        # Lake cache populated by another configuration or checkout.
        settings = {"LAKE_CONFIG": str(config), "LAKE_ARTIFACT_CACHE": "true",
                    "LAKE_RESTORE_ARTIFACTS": "true",
                    "CURL": str(SCRIPTS / "lake_cache_curl.py")}
        env = dict(os.environ, **settings)
        for library, _, _ in services:
            retry(["lake", "-v", "cache", "get", "--service", f"{library.prefix.lower()}-public",
                   "--repo", library.repo, "--package", library.package,
                   "--rev", packages[library.package]["rev"], "--mappings-only"], project, env, 3)
        if restore:
            # leantar's recursive decoder needs more than the usual 8 MiB for
            # TauCeti.Algebra.Lie.F4.ModularLattice on Lean 4.37.0-rc1.
            # Raise only this helper's soft limit; Lake and its extractor inherit
            # it. Respect a finite hard limit and never lower a larger allowance.
            soft, hard = resource.getrlimit(resource.RLIMIT_STACK)
            stack = 64 * 1024 * 1024
            if hard != resource.RLIM_INFINITY:
                stack = min(stack, hard)
            if soft != resource.RLIM_INFINITY and soft < stack:
                resource.setrlimit(resource.RLIMIT_STACK, (stack, hard))
            targets = sorted({m for m in modules if any(belongs(m, lib) for lib in needed)})
            print(f"fetch_dependency_caches: restoring {len(targets)} imported library module(s) "
                  "and their dependencies", file=sys.stderr)
            # `+` selects a module even when a library has the same name;
            # a bare name could otherwise restore every module of that library.
            log = retry(["lake", "-v", "--no-build", "build", *("+" + m for m in targets)],
                        project, env, 2)
            roots = "|".join(re.escape(root) for lib in needed for root in lib.roots)
            if re.search(rf"Built (?:{roots})(?:[.\s]|$)", log):
                raise RuntimeError("a dependency module was compiled instead of downloaded:\n" + log)
        return settings
    except BaseException:
        config.unlink(missing_ok=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", action="store_true")
    parser.add_argument("project", type=Path)
    args = parser.parse_args()
    try:
        settings = prepare(args.project.resolve(), args.restore)
        if settings:
            if github_env := os.environ.get("GITHUB_ENV"):
                with open(github_env, "a", encoding="utf-8") as output:
                    for name, value in settings.items():
                        output.write(f"{name}={value}\n")
            else:
                print("export " + " ".join(f"{name}={shlex.quote(value)}"
                                           for name, value in settings.items()))
        return 0
    except (OSError, ValueError, RuntimeError) as error:
        print(f"::error::fetch_dependency_caches: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
