#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys

import generate_projects as gp


def main() -> int:
    manifest_path = pathlib.Path("manifests/problems.toml")
    try:
        problems = gp.load_manifest(manifest_path)
        gp.validate_problems(problems)
        gp.validate_manifest_against_inventory(problems)
        gp.validate_theorem_proof_shape(problems)
    except gp.GenerationError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print("Manifest and @[eval_problem] declarations are consistent.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

