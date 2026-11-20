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

from prepare_toolchain import SUPPORT_ROLES, configurations


CONFIGURATIONS = SUPPORT_ROLES
ROOT = Path(__file__).resolve().parents[1]


def supported_configurations(problem: dict) -> tuple[str, ...]:
    value = problem.get("supported_configurations", list(CONFIGURATIONS))
    if not isinstance(value, list) or not value or any(not isinstance(v, str) for v in value):
        raise ValueError("supported_configurations must be a nonempty list of configuration names")
    supported = tuple(name for name in CONFIGURATIONS if name in value)
    if len(set(value)) != len(value) or set(value) != set(supported) or supported != CONFIGURATIONS[:len(supported)]:
        raise ValueError("supported_configurations must be ['latest'], ['latest', 'rc'], "
                         "['latest', 'rc', 'stable'], or ['latest', 'rc', 'stable', 'previous-stable']")
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
    for alias in (*CONFIGURATIONS, *registry.get("variants", {})):
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
    if configuration in registry.get("variants", {}):
        configurations(root)
        return configuration
    raise ValueError(f"unknown configuration: {configuration}")


def configuration_policy(root: Path, configuration: str) -> tuple[str, frozenset[str]]:
    if configuration in CONFIGURATIONS:
        return configuration, frozenset()
    configurations(root)
    registry = json.loads((root / "supported-toolchains.json").read_text())
    variant = registry.get("variants", {}).get(configuration)
    if variant is None:
        raise ValueError(f"unknown configuration: {configuration}")
    unavailable = frozenset(variant.get("unsupported_modules", []))
    known = {p["module"] for p in load_problems(root).values()}
    if unavailable - known:
        raise ValueError(f"{configuration}: unknown unsupported modules: {', '.join(sorted(unavailable - known))}")
    return variant["support_role"], unavailable


def require_supported(root: Path, configuration: str, problems: list[str]) -> None:
    known = load_problems(root)
    role, unavailable = configuration_policy(root, configuration)
    for name in problems:
        if name not in known:
            raise ValueError(f"unknown problem: {name}")
        supported = supported_configurations(known[name])
        if role not in supported:
            raise ValueError(f"{name} does not support {configuration}; choose {', '.join(supported)}")
        if unavailable and known[name]["module"] in unavailable:
            raise ValueError(f"{name} is unavailable in {configuration}; choose {role}")


def compatible_modules(root: Path, configuration: str, requested: list[str]) -> list[str]:
    problems = load_problems(root)
    role, unavailable = configuration_policy(root, configuration)
    known = {problem["module"] for problem in problems.values()}
    unknown = set(requested) - known
    if unknown:
        raise ValueError(f"unknown problem modules: {', '.join(sorted(unknown))}")
    selected = set(requested) if requested else known
    return sorted({problem["module"] for problem in problems.values()
                   if problem["module"] in selected and problem["module"] not in unavailable
                   and role in supported_configurations(problem)})


def check_no_regressions(root: Path, base: str) -> None:
    current = load_problems(root)
    registry_path = root / "supported-toolchains.json"
    variants = json.loads(registry_path.read_text()).get("variants", {}) if registry_path.is_file() else {}
    previous_registry = subprocess.run(["git", "show", f"{base}:supported-toolchains.json"],
                                       cwd=root, capture_output=True, text=True)
    previous_variants = json.loads(previous_registry.stdout).get("variants", {}) if previous_registry.returncode == 0 else {}
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
            for name in variants.keys() & previous_variants.keys():
                old, new = previous_variants[name], variants[name]
                was_supported = (old["support_role"] in supported_configurations(previous)
                                 and previous["module"] not in old.get("unsupported_modules", []))
                is_supported = (new["support_role"] in supported_configurations(current[path.stem])
                                and current[path.stem]["module"] not in new.get("unsupported_modules", []))
                if was_supported and not is_supported:
                    raise ValueError(f"{path.stem}: compatibility would decrease for {name}; "
                                     "fix the problem for the upgraded dependencies instead")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--configuration", default="current", help="Support role, library variant, or current")
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
            role, unavailable = configuration_policy(args.root, configuration)
            print(json.dumps([name for name, problem in problems.items()
                              if role in supported_configurations(problem)
                              and (not unavailable or problem["module"] not in unavailable)]))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"problem_configurations: {error}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
