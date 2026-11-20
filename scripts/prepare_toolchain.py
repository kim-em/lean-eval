#!/usr/bin/env python3
"""Select a benchmark-owned toolchain configuration in an isolated checkout.

Use --destination to create a separate working copy, or --apply in a fresh CI
checkout before fetching dependencies. Regenerate selected workspaces afterwards;
generated statements and build outputs must come from the selected configuration.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import sys


ROOT = Path(__file__).resolve().parents[1]
FILES = ("lean-toolchain", "lakefile.toml", "lake-manifest.json")
SUPPORT_ROLES = ("latest", "rc", "stable", "previous-stable")


def configurations(root: Path) -> tuple[str, dict[str, Path]]:
    data = json.loads((root / "supported-toolchains.json").read_text())
    result = {}
    for configuration, relative in data["configurations"].items():
        path = (root / relative).resolve()
        if not path.is_relative_to(root.resolve()):
            raise ValueError("toolchain configuration escapes the benchmark")
        if configuration.startswith("leanprover/lean4:") and (
                path / "lean-toolchain").read_text().strip() != configuration:
            raise ValueError(f"toolchain configuration disagrees with its pin: {configuration}")
        for name in FILES:
            if (path / name).is_symlink() or not (path / name).is_file():
                raise ValueError(f"missing regular configuration file: {path / name}")
        result[configuration] = path
    if any(data[alias] not in result
           for alias in ("default", *SUPPORT_ROLES) if alias in data):
        raise ValueError("a configured default, stable, previous-stable, rc or latest alias has no configuration")
    variants = data.get("variants", {})
    if not isinstance(variants, dict):
        raise ValueError("configuration variants must be an object")
    reserved = {"default", *SUPPORT_ROLES, *(data.get(role) for role in SUPPORT_ROLES)}
    for name, variant in variants.items():
        if name in reserved or name not in result or not isinstance(variant, dict):
            raise ValueError(f"invalid configuration variant: {name}")
        if variant.get("support_role") not in SUPPORT_ROLES or variant["support_role"] not in data:
            raise ValueError(f"configuration variant {name} has no supported role")
        canonical = result[data[variant["support_role"]]]
        if (result[name] / "lean-toolchain").read_text().strip() != (canonical / "lean-toolchain").read_text().strip():
            raise ValueError(f"configuration variant {name} must use its support role's Lean toolchain")
        unavailable = variant.get("unsupported_modules", [])
        if (not isinstance(unavailable, list) or any(not isinstance(m, str) or not m for m in unavailable)
                or len(set(unavailable)) != len(unavailable)):
            raise ValueError(f"configuration variant {name} has invalid unsupported modules")
    return data["default"], result


def prepare(root: Path, toolchain: str, destination: Path | None = None) -> Path:
    default, supported = configurations(root)
    registry = json.loads((root / "supported-toolchains.json").read_text())
    stable = registry["stable"]
    toolchain = {"stable": stable, "default": default,
                 "previous-stable": registry.get("previous-stable", "previous-stable"),
                 "rc": registry.get("rc", default),
                 "latest": registry.get("latest", "latest")}.get(toolchain, toolchain)
    if toolchain not in supported:
        raise ValueError(f"unsupported toolchain {toolchain!r}; choose {', '.join(supported)}")
    # Read everything before mutation, including when the chosen configuration
    # is the root itself. Build artifacts are never reused between toolchains.
    contents = {name: (supported[toolchain] / name).read_bytes() for name in FILES}
    target = root if destination is None else destination.resolve()
    if destination is None:
        if (root / ".lake").exists() or (root / ".lake").is_symlink():
            raise ValueError("--apply requires a fresh checkout without .lake; use --destination")
    else:
        if target.exists():
            raise ValueError(f"destination already exists: {target}")
        if target.is_relative_to(root.resolve()) and ".lake" not in target.relative_to(root).parts:
            raise ValueError("an in-tree destination must be under .lake")
        shutil.copytree(root, target, ignore=shutil.ignore_patterns(
            ".git", ".lake", ".cache", "build", "workspaces", "__pycache__"))
    for name, content in contents.items():
        (target / name).write_bytes(content)
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("toolchain")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--destination", type=Path)
    mode.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    try:
        print(prepare(ROOT, args.toolchain, args.destination))
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"prepare_toolchain: {error}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
