#!/usr/bin/env python3
"""Select and shard the catalog work needed for a CI change.

Pull requests validate changed problem modules and every manifest root that
imports them, transitively. Lean itself parses module headers and provides the
dependency graph consumed here. Changes to shared generator/infrastructure
inputs are conservative full-catalog sentinels. Relevant pushes validate the
full catalog; documentation-only pushes do not launch catalog shards.
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import os
import pathlib
import re
import subprocess
import sys
import tomllib
from collections import defaultdict, deque
from collections.abc import Iterable, Sequence


PROBLEM_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")
ZERO_SHA = "0" * 40


@dataclasses.dataclass(frozen=True)
class Problem:
    id: str
    module: str


@dataclasses.dataclass(frozen=True)
class Change:
    status: str
    paths: tuple[str, ...]


@dataclasses.dataclass(frozen=True)
class Selection:
    mode: str
    reasons: tuple[str, ...]
    problems: tuple[str, ...]
    modules: tuple[str, ...]
    source_changed: bool
    generated_changed: bool
    run_checks: bool

    @property
    def run_catalog(self) -> bool:
        return bool(self.problems)


def load_problems(root: pathlib.Path) -> tuple[Problem, ...]:
    problems: list[Problem] = []
    seen_ids: set[str] = set()
    for path in sorted((root / "manifests" / "problems").glob("*.toml")):
        data = tomllib.loads(path.read_text(encoding="utf-8"))
        problem_id = data["id"]
        module = data["module"]
        if problem_id != path.stem or PROBLEM_ID_RE.fullmatch(problem_id) is None:
            raise ValueError(f"unsafe or mismatched problem id in {path}: {problem_id!r}")
        if problem_id in seen_ids:
            raise ValueError(f"duplicate problem id in CI selector: {problem_id}")
        if not module.startswith("LeanEval.") or any(char in module for char in ",\r\n"):
            raise ValueError(f"unsafe problem module in {path}: {module!r}")
        seen_ids.add(problem_id)
        problems.append(Problem(id=problem_id, module=module))
    return tuple(problems)


def load_import_graph(path: pathlib.Path) -> tuple[dict[str, str], dict[str, set[str]]]:
    """Load the graph emitted by the Lean `ci_import_graph` executable."""
    try:
        entries = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot load Lean import graph from {path}: {error}") from error
    if not isinstance(entries, list):
        raise ValueError("Lean import graph must be a JSON array")

    paths: dict[str, str] = {}
    imports: dict[str, set[str]] = {}
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise ValueError(f"Lean import graph entry {index} must be an object")
        relative = entry.get("path")
        module = entry.get("module")
        imported_modules = entry.get("imports")
        if (
            not isinstance(relative, str)
            or not relative.startswith("LeanEval/")
            or not relative.endswith(".lean")
            or any(char in relative for char in "\0\r\n")
        ):
            raise ValueError(f"Lean import graph entry {index} has an unsafe path: {relative!r}")
        if (
            not isinstance(module, str)
            or not module.startswith("LeanEval.")
            or any(char in module for char in "\0\r\n")
        ):
            raise ValueError(f"Lean import graph entry {index} has an unsafe module: {module!r}")
        if not isinstance(imported_modules, list) or not all(
            isinstance(imported, str) for imported in imported_modules
        ):
            raise ValueError(f"Lean import graph entry {index} has invalid imports")
        if relative in paths:
            raise ValueError(f"duplicate path in Lean import graph: {relative}")
        if module in imports:
            raise ValueError(f"duplicate module in Lean import graph: {module}")
        paths[relative] = module
        imports[module] = {
            imported for imported in imported_modules if imported.startswith("LeanEval.")
        }
    return paths, imports


def parse_git_changes(output: bytes) -> tuple[Change, ...]:
    """Parse `git diff --name-status -z` without Git path quoting."""
    fields = output.split(b"\0")
    if not fields or fields[-1] != b"":
        raise ValueError("git diff output is not NUL terminated")
    fields.pop()
    changes: list[Change] = []
    index = 0
    while index < len(fields):
        status = os.fsdecode(fields[index])
        index += 1
        path_count = 2 if status.startswith(("C", "R")) else 1
        if not status or index + path_count > len(fields):
            raise ValueError(f"unexpected git diff record near status {status!r}")
        paths = tuple(os.fsdecode(field) for field in fields[index:index + path_count])
        index += path_count
        changes.append(Change(status, paths))
    return tuple(changes)


def git_changes(root: pathlib.Path, base: str, head: str, event: str) -> tuple[Change, ...]:
    if base == ZERO_SHA:
        return (Change("A", ("<initial-push>",)),)
    if event == "pull_request":
        # The base branch may have advanced after the contributor branched.
        # Comparing its tip directly to the PR head treats base-only changes
        # as reversions by the PR, triggering unrelated catalog checks.
        ancestor = subprocess.run(
            ["git", "merge-base", base, head],
            cwd=root,
            check=True,
            stdout=subprocess.PIPE,
            text=True,
        )
        base = ancestor.stdout.strip()
    result = subprocess.run(
        ["git", "diff", "--name-status", "-z", "--find-renames", f"{base}..{head}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    )
    return parse_git_changes(result.stdout)


def reverse_dependants(imports: dict[str, set[str]], changed: Iterable[str]) -> set[str]:
    reverse: dict[str, set[str]] = defaultdict(set)
    for module, dependencies in imports.items():
        for dependency in dependencies:
            reverse[dependency].add(module)
    reached = set(changed)
    queue = deque(changed)
    while queue:
        dependency = queue.popleft()
        for dependant in reverse.get(dependency, ()):
            if dependant not in reached:
                reached.add(dependant)
                queue.append(dependant)
    return reached


def is_full_catalog_sentinel(path: str) -> bool:
    return (
        path.startswith("EvalTools/")
        or path.startswith("templates/")
        or path.startswith("manifests/sets/")
        or path.startswith(".github/actions/")
        or path == ".github/workflows/ci.yml"
        or path == "manifests/tags.toml"
        or path == "scripts/select_ci_problems.py"
        or path == "scripts/prepare_toolchain.py"
        or path == "scripts/prepare_ci_dependencies.py"
        or path == "scripts/select_submission_toolchain.py"
        or path == "scripts/problem_configurations.py"
        or path == "supported-toolchains.json"
        or path.startswith("toolchains/")
        or path in {"lakefile.toml", "lake-manifest.json", "lean-toolchain", "solution-dependencies.json"}
    )


def select(
    root: pathlib.Path,
    event: str,
    changes: Sequence[Change],
    problems: Sequence[Problem] | None = None,
    graph: tuple[dict[str, str], dict[str, set[str]]] | None = None,
) -> Selection:
    problems = tuple(problems if problems is not None else load_problems(root))
    by_id = {problem.id: problem for problem in problems}
    by_module: dict[str, set[str]] = defaultdict(set)
    for problem in problems:
        by_module[problem.module].add(problem.id)

    changed_paths = [path for change in changes for path in change.paths]
    source_changed = any(
        path.startswith(("LeanEval/", "EvalTools/", "templates/", "manifests/", "toolchains/"))
        or path in {"supported-toolchains.json", "scripts/prepare_toolchain.py"}
        or path in {"lakefile.toml", "lake-manifest.json", "lean-toolchain", "solution-dependencies.json"}
        for path in changed_paths
    )
    generated_changed = any(path.startswith("generated/") for path in changed_paths)
    infrastructure_changed = any(
        path.startswith((".github/workflows/", ".github/actions/", "scripts/", "tests/"))
        for path in changed_paths
    )
    run_checks = source_changed or generated_changed or infrastructure_changed

    all_ids = tuple(sorted(by_id))
    all_modules = tuple(sorted(by_module))
    initial_push = "<initial-push>" in changed_paths
    documentation_only = bool(changed_paths) and all(
        path.startswith("docs/")
        or ("/" not in path and path.endswith(".md"))
        for path in changed_paths
    )
    if event == "push" and not documentation_only:
        return Selection(
            "full", ("initial push" if initial_push else "non-documentation push to main",),
            all_ids, all_modules,
            source_changed, generated_changed, run_checks,
        )

    sentinel_paths = sorted({path for path in changed_paths if is_full_catalog_sentinel(path)})
    destructive = [
        change
        for change in changes
        if change.status.startswith(("D", "R"))
        and any(
            path.startswith(("LeanEval/", "manifests/"))
            for path in change.paths
        )
    ]
    if sentinel_paths or destructive:
        reasons = []
        if sentinel_paths:
            reasons.append("full-catalog sentinel: " + ", ".join(sentinel_paths))
        if destructive:
            reasons.append("deleted or renamed path")
        return Selection(
            "full", tuple(reasons), all_ids, all_modules,
            source_changed, generated_changed, run_checks,
        )

    selected_ids: set[str] = set()
    changed_source_paths: set[str] = set()
    reasons: list[str] = []
    for path in changed_paths:
        if path.startswith("manifests/problems/"):
            if path.endswith(".toml"):
                problem_id = pathlib.PurePosixPath(path).stem
                if problem_id in by_id:
                    selected_ids.add(problem_id)
                    reasons.append(f"manifest {problem_id}")
        elif path.startswith("generated/"):
            parts = pathlib.PurePosixPath(path).parts
            if len(parts) >= 2 and parts[1] in by_id:
                selected_ids.add(parts[1])
                reasons.append(f"generated workspace {parts[1]}")
        elif path.startswith("LeanEval/") and path.endswith(".lean"):
            changed_source_paths.add(path)

    if changed_source_paths:
        if graph is None:
            return Selection(
                "full", ("Lean import graph unavailable",), all_ids, all_modules,
                source_changed, generated_changed, run_checks,
            )
        path_modules, imports = graph
        missing = sorted(changed_source_paths - path_modules.keys())
        if missing:
            return Selection(
                "full", ("changed source missing from graph: " + ", ".join(missing),),
                all_ids, all_modules, source_changed, generated_changed, run_checks,
            )
        changed_modules = {path_modules[path] for path in changed_source_paths}
        affected_modules = reverse_dependants(imports, changed_modules)
        affected_roots = affected_modules & by_module.keys()
        for module in affected_roots:
            selected_ids.update(by_module[module])
        reasons.append(
            f"{len(changed_modules)} changed module(s), {len(affected_roots)} affected manifest root(s)"
        )

    # Keep all problems sharing a selected module together.  Inventory
    # validation is module-scoped, so splitting such entries would make tagged
    # declarations from the other half look untracked.
    selected_modules = {by_id[problem_id].module for problem_id in selected_ids}
    for module in selected_modules:
        selected_ids.update(by_module[module])

    return Selection(
        "targeted" if selected_ids else "none",
        tuple(dict.fromkeys(reasons)),
        tuple(sorted(selected_ids)),
        tuple(sorted(selected_modules)),
        source_changed,
        generated_changed,
        run_checks,
    )


def make_matrix(selection: Selection, problems: Sequence[Problem], shard_limit: int) -> dict:
    by_module: dict[str, list[str]] = defaultdict(list)
    selected = set(selection.problems)
    for problem in problems:
        if problem.id in selected:
            by_module[problem.module].append(problem.id)
    if not by_module:
        # GitHub validates a matrix before evaluating the job-level `if`.
        return {"include": [{"shard": 0, "shard_count": 1, "problems": "", "modules": ""}]}

    shard_count = min(shard_limit, len(by_module))
    shards: list[list[str]] = [[] for _ in range(shard_count)]
    weights = [0] * shard_count
    for module, module_problems in sorted(by_module.items(), key=lambda item: (-len(item[1]), item[0])):
        shard = min(range(shard_count), key=lambda index: (weights[index], index))
        shards[shard].append(module)
        weights[shard] += len(module_problems)

    include = []
    for index, modules in enumerate(shards):
        modules.sort()
        problem_ids = sorted(problem for module in modules for problem in by_module[module])
        include.append({
            "shard": index,
            "shard_count": shard_count,
            "problems": ",".join(problem_ids),
            "modules": ",".join(modules),
        })
    return {"include": include}


def write_github_output(path: pathlib.Path, selection: Selection, matrix: dict) -> None:
    values = {
        "source_changed": str(selection.source_changed).lower(),
        "generated_changed": str(selection.generated_changed).lower(),
        "run_checks": str(selection.run_checks).lower(),
        "run_catalog": str(selection.run_catalog).lower(),
        "selection_mode": selection.mode,
        "selected_problem_count": str(len(selection.problems)),
        "selected_modules": ",".join(selection.modules),
        "matrix": json.dumps(matrix, separators=(",", ":")),
    }
    with path.open("a", encoding="utf-8") as output:
        for key, value in values.items():
            output.write(f"{key}={value}\n")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path("."))
    parser.add_argument("--event", choices=("push", "pull_request"), required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--shards", type=int, default=8)
    parser.add_argument("--import-graph", type=pathlib.Path, required=True)
    parser.add_argument("--github-output", type=pathlib.Path)
    args = parser.parse_args(argv)
    if args.shards <= 0:
        parser.error("--shards must be positive")
    root = args.root.resolve()
    problems = load_problems(root)
    changes = git_changes(root, args.base, args.head, args.event)
    graph = load_import_graph(args.import_graph)
    selection = select(root, args.event, changes, problems, graph)
    matrix = make_matrix(selection, problems, args.shards)
    print(
        f"Catalog selection: {selection.mode}; {len(selection.problems)} problem(s), "
        f"{len(selection.modules)} module(s)"
    )
    for reason in selection.reasons:
        print(f"  - {reason}")
    if args.github_output is not None:
        write_github_output(args.github_output, selection, matrix)
    else:
        print(json.dumps(matrix, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
