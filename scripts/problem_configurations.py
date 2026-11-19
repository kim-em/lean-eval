#!/usr/bin/env python3
"""Validate problem compatibility, select supported work, and prevent regressions."""
from __future__ import annotations

import argparse
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tomllib

from prepare_toolchain import configurations


CONFIGURATIONS = ("latest", "rc", "stable")
ROOT = Path(__file__).resolve().parents[1]


def supported_configurations(problem: dict) -> tuple[str, ...]:
    value = problem.get("supported_configurations", list(CONFIGURATIONS))
    if not isinstance(value, list) or not value or any(not isinstance(v, str) for v in value):
        raise ValueError("supported_configurations must be a nonempty list of configuration names")
    supported = tuple(name for name in CONFIGURATIONS if name in value)
    if len(set(value)) != len(value) or set(value) != set(supported) or supported != CONFIGURATIONS[:len(supported)]:
        raise ValueError("supported_configurations must be ['latest'], ['latest', 'rc'], "
                         "or ['latest', 'rc', 'stable']")
    return supported


def load_problems(root: Path) -> dict[str, dict]:
    result = {}
    for path in sorted((root / "manifests/problems").glob("*.toml")):
        problem = tomllib.loads(path.read_text())
        try:
            supported_configurations(problem)
        except ValueError as error:
            raise ValueError(f"{path}: {error}") from error
        result[path.stem] = problem
    return result


def current_configuration(root: Path) -> str:
    registry = json.loads((root / "supported-toolchains.json").read_text())
    _, profiles = configurations(root)
    for alias in CONFIGURATIONS:
        profile = profiles.get(registry.get(alias, registry["default"] if alias == "rc" else alias))
        if profile is None:
            continue
        if all((root / name).read_bytes() == (profile / name).read_bytes()
               for name in ("lean-toolchain", "lakefile.toml", "lake-manifest.json")):
            return alias
    raise ValueError("workspace does not match an approved configuration; run prepare_toolchain.py")


def configuration_alias(root: Path, configuration: str) -> str:
    registry = json.loads((root / "supported-toolchains.json").read_text())
    for alias in CONFIGURATIONS:
        if registry.get(alias, registry["default"] if alias == "rc" else alias) == configuration:
            return alias
    raise ValueError(f"unknown configuration: {configuration}")


def require_supported(root: Path, configuration: str, problems: list[str]) -> None:
    known = load_problems(root)
    for name in problems:
        if name not in known:
            raise ValueError(f"unknown problem: {name}")
        supported = supported_configurations(known[name])
        if configuration not in supported:
            raise ValueError(f"{name} does not support {configuration}; choose {', '.join(supported)}")


def compatible_modules(root: Path, configuration: str, requested: list[str]) -> list[str]:
    problems = load_problems(root)
    known = {problem["module"] for problem in problems.values()}
    unknown = set(requested) - known
    if unknown:
        raise ValueError(f"unknown problem modules: {', '.join(sorted(unknown))}")
    selected = set(requested) if requested else known
    return sorted({problem["module"] for problem in problems.values()
                   if problem["module"] in selected and configuration in supported_configurations(problem)})


def check_no_regressions(root: Path, base: str) -> None:
    current = load_problems(root)
    archive = subprocess.check_output(["git", "archive", base, "manifests/problems"], cwd=root)
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        for member in source:
            path = Path(member.name)
            if not member.isfile() or path.suffix != ".toml":
                continue
            previous = tomllib.loads(source.extractfile(member).read().decode())
            if path.stem not in current:
                raise ValueError(f"{path.stem}: removing a problem loses its supported configurations; "
                                 "archive it in the manifest instead")
            lost = set(supported_configurations(previous)) - set(supported_configurations(current[path.stem]))
            if lost:
                raise ValueError(f"{path.stem}: compatibility would decrease for {', '.join(sorted(lost))}; "
                                 "fix the problem for the upgraded dependencies instead")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--configuration", choices=(*CONFIGURATIONS, "current"), default="current")
    parser.add_argument("--base")
    parser.add_argument("--modules", help="Filter a comma-separated list of modules; an empty list selects all")
    parser.add_argument("--problem", action="append", default=[])
    parser.add_argument("--list-problems", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        problems = load_problems(args.root)
        if args.base:
            check_no_regressions(args.root, args.base)
        configuration = current_configuration(args.root) if args.configuration == "current" else args.configuration
        require_supported(args.root, configuration, args.problem)
        if args.modules is not None:
            selected = compatible_modules(args.root, configuration, list(filter(None, args.modules.split(","))))
            print(json.dumps(selected) if args.json else ",".join(selected))
        elif args.list_problems:
            print(json.dumps([name for name, problem in problems.items()
                              if configuration in supported_configurations(problem)]))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"problem_configurations: {error}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
