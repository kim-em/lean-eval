#!/usr/bin/env python3
"""Read toolchain requests from archived source without extracting or executing it.

The closest lean-toolchain and the workspace's Mathlib/TauCeti pins select an
approved benchmark configuration, including configurations sharing Lean.
Missing pins use the default. One archive must select one configuration.
Archive mode retains invalid requests using the
default; evaluation rejects them after the source has been durably archived.
"""
from __future__ import annotations

import argparse
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tarfile
import tomllib

from prepare_toolchain import FILES, ROOT, configurations, prepare
from problem_configurations import configuration_alias, require_supported


class ToolchainRequestError(ValueError):
    """Archived source cannot select an approved evaluation configuration."""


def dependency_pins(lakefile: dict) -> dict[str, str]:
    """Read only the two dependencies that identify approved library snapshots."""
    requirements = lakefile.get("require", [])
    if not isinstance(requirements, list):
        raise ValueError("workspace requirements must be an array of tables")
    result = {}
    for dependency in requirements:
        if not isinstance(dependency, dict) or dependency.get("name") not in {"mathlib", "TauCeti"}:
            continue
        name = dependency["name"]
        if name in result or not isinstance(dependency.get("rev"), str):
            raise ValueError(f"{name} must have one exact dependency pin")
        result[name] = dependency["rev"]
    return result


def resolve_configuration(root: Path, requested: str | None, dependencies: dict[str, str]) -> str:
    default, supported = configurations(root)
    toolchain = requested if requested is not None else (
        supported[default] / "lean-toolchain").read_text().strip()
    candidates = {name: path for name, path in supported.items()
                  if (path / "lean-toolchain").read_text().strip() == toolchain}
    if not candidates:
        raise ValueError(f"unsupported requested toolchain {toolchain!r}")
    if dependencies:
        candidates = {name: path for name, path in candidates.items()
                      if all(dependency_pins(tomllib.loads((path / "lakefile.toml").read_text())).get(
                          dependency) == revision for dependency, revision in dependencies.items())}
        if not candidates:
            raise ValueError("unsupported Mathlib/TauCeti pins for the requested toolchain; "
                             "regenerate the workspace from an approved configuration")
    if default in candidates:
        return default
    if toolchain in candidates:
        return toolchain
    if len(candidates) != 1:
        raise ValueError("ambiguous configuration; include the generated workspace's dependency pins")
    return next(iter(candidates))


def source_requests(archive: Path, root: Path, default: str,
                    problem: str | None = None) -> dict[str, str | None]:
    known = {p.stem for p in (root / "manifests/problems").glob("*.toml")}
    if problem is not None:
        if problem not in known:
            raise ValueError(f"unknown problem: {problem}")
        known = {problem}
    pins: dict[PurePosixPath, str | ValueError] = {}
    workspaces: dict[PurePosixPath, tuple[str, dict[str, str]]] = {}
    submissions: dict[PurePosixPath, bytes | None] = {}
    # Sequential traversal also handles compressed archives without creating
    # a second extracted copy alongside the encrypted archive job's source.
    seen = set()
    with tarfile.open(archive, mode="r|gz") as source:
        for member in source:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts:
                raise ValueError("source archive contains an escaping path")
            if path.name not in {"lean-toolchain", "lakefile.toml", "Submission.lean"}:
                continue
            if path in seen:
                raise ValueError(f"duplicate source configuration: {path}")
            seen.add(path)
            if not member.isfile():
                if path.name == "lean-toolchain":
                    pins[path.parent] = ValueError(f"lean-toolchain must be a regular file: {path}")
                continue
            handle = source.extractfile(member)
            if path.name == "lean-toolchain":
                if member.size > 256:
                    pins[path.parent] = ValueError(f"oversized lean-toolchain: {path}")
                    continue
                try:
                    pins[path.parent] = handle.read().decode("ascii").strip()
                except UnicodeError:
                    pins[path.parent] = ValueError(f"lean-toolchain is not ASCII: {path}")
            elif path.name == "lakefile.toml":
                if member.size > 1024 * 1024:
                    continue
                try:
                    lakefile = tomllib.loads(handle.read().decode("utf-8"))
                    name = lakefile.get("name")
                except (ValueError, UnicodeError):
                    continue
                if isinstance(name, str) and name in known:
                    workspaces[path.parent] = name, dependency_pins(lakefile)
            else:
                # Stubs are small. Larger submissions can never equal a
                # pristine stub, so do not retain their contents in memory.
                submissions[path.parent] = handle.read(65537)
    result = {}
    for directory, (name, dependencies) in workspaces.items():
        if directory not in submissions:
            continue
        stub = root / "generated" / name / "Submission.lean"
        if stub.is_file() and submissions[directory] == stub.read_bytes():
            continue
        requested = next((pins[parent] for parent in [directory, *directory.parents]
                          if parent in pins), None)
        if isinstance(requested, ValueError):
            raise requested
        requested = resolve_configuration(root, requested, dependencies)
        previous = result.get(name)
        if name in result and (default if previous is None else previous) != (
                default if requested is None else requested):
            raise ValueError(f"multiple configurations requested for {name}")
        result[name] = requested
    return result


def select(archive: Path, root: Path, problem: str | None = None) -> tuple[str, list[str]]:
    default, supported = configurations(root)
    try:
        requests = source_requests(archive, root, default, problem)
    except Exception as error:
        # TOML and archive readers can also raise RecursionError or resource
        # errors on malformed source. No source parser failure may block its
        # archival, and evaluation treats it as a terminal input rejection.
        raise ToolchainRequestError(str(error)) from error
    requested = {pin if pin is not None else default for pin in requests.values()}
    if not requested:
        requested = {default}
    if len(requested) != 1:
        raise ToolchainRequestError("one submission must use one toolchain and dependency configuration; "
                                    "submit the workspaces separately")
    configuration = requested.pop()
    if configuration not in supported:
        raise ToolchainRequestError(f"unsupported requested configuration {configuration!r}")
    try:
        require_supported(root, configuration_alias(root, configuration), sorted(requests))
    except ValueError as error:
        raise ToolchainRequestError(str(error)) from error
    return configuration, sorted(requests)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-tar", required=True, type=Path)
    parser.add_argument("--problem")
    parser.add_argument("--archive", action="store_true")
    parser.add_argument("--expected")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--regenerate", action="store_true")
    args = parser.parse_args()
    try:
        try:
            configuration, problems = select(args.source_tar, ROOT, args.problem)
        except ToolchainRequestError as error:
            if not args.archive:
                raise
            print(f"Retaining invalid toolchain request for evaluation to reject: {error}", file=sys.stderr)
            configuration, problems = configurations(ROOT)[0], []
        profile = configurations(ROOT)[1][configuration]
        toolchain = (profile / "lean-toolchain").read_text().strip()
        if args.expected is not None and args.expected != toolchain:
            raise ValueError("source toolchain disagrees with the archived evaluation toolchain")
        if args.apply:
            prepare(ROOT, configuration)
        if args.regenerate:
            if any((ROOT / name).read_bytes() != (profile / name).read_bytes() for name in FILES):
                raise ValueError("select the requested configuration before regenerating")
            for problem in problems:
                subprocess.run(["lake", "exe", "lean-eval", "generate", "--problem", problem],
                               cwd=ROOT, check=True, stdout=sys.stderr)
        print(toolchain)
    except ToolchainRequestError as error:
        parser.exit(3, f"select_submission_toolchain: {error}\n")
    except (OSError, ValueError, UnicodeError, tarfile.TarError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"select_submission_toolchain: {error}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
