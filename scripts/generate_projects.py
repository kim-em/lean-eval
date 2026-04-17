#!/usr/bin/env python3
"""
Generate one comparator workspace per problem in the manifest.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tomllib
from dataclasses import dataclass
from typing import Callable


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPO_ROOT / "manifests" / "problems.toml"
GENERATED_ROOT = REPO_ROOT / "generated"
FIXED_AXIOMS = ["propext", "Quot.sound", "Classical.choice"]
ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")
EXPECTED_FILES = {
    "README.md",
    "lean-toolchain",
    "lakefile.toml",
    "ChallengeDeps.lean",
    "Challenge.lean",
    "Solution.lean",
    "Submission.lean",
    "Submission/Helpers.lean",
    "WorkspaceTest.lean",
    "config.json",
}
IGNORED_PATH_NAMES = {".lake", "build", ".cache", "lake-manifest.json"}


def _theorem_by_pattern(theorem_name: str) -> re.Pattern[str]:
    return re.compile(
        rf"(?:^|\s)theorem\s+{re.escape(theorem_name)}\b(?P<body>.*?)(?:\s*:=\s*by\b)",
        re.DOTALL,
    )


class GenerationError(Exception):
    pass


@dataclass(frozen=True)
class ProblemSpec:
    id: str
    title: str
    test: bool
    module: str
    theorem: str
    submitter: str
    notes: str | None = None
    source: str | None = None
    informal_solution: str | None = None


@dataclass(frozen=True)
class ExtractedTheorem:
    declaration_name: str
    module: str
    source_range: tuple[int, int, int, int]
    same_module_dependencies: tuple[str, ...]


@dataclass(frozen=True)
class DependencySpec:
    name: str
    git: str
    rev: str


@dataclass(frozen=True)
class InventoryEntry:
    module: str
    declaration_name: str
    basename: str


def load_root_mathlib_dependency(path: pathlib.Path | None = None) -> DependencySpec:
    if path is None:
        path = REPO_ROOT / "lakefile.toml"
    with path.open("rb") as handle:
        data = tomllib.load(handle)

    raw_requirements = data.get("require", [])
    if not isinstance(raw_requirements, list):
        raise GenerationError(f"Expected [[require]] entries in {path}")

    mathlib_entries = [
        raw_requirement
        for raw_requirement in raw_requirements
        if isinstance(raw_requirement, dict) and raw_requirement.get("name") == "mathlib"
    ]
    if not mathlib_entries:
        raise GenerationError(f"Could not find a mathlib dependency in {path}")
    if len(mathlib_entries) > 1:
        raise GenerationError(f"Found multiple mathlib dependencies in {path}")

    entry = mathlib_entries[0]
    git = entry.get("git")
    rev = entry.get("rev")
    if not isinstance(git, str) or not git.strip():
        raise GenerationError(f"mathlib dependency in {path} is missing a non-empty 'git' field")
    if not isinstance(rev, str) or not rev.strip():
        raise GenerationError(f"mathlib dependency in {path} is missing a non-empty 'rev' field")

    return DependencySpec(name="mathlib", git=git.strip(), rev=rev.strip())


def load_manifest(path: pathlib.Path) -> list[ProblemSpec]:
    with path.open("rb") as handle:
        data = tomllib.load(handle)

    raw_problems = data.get("problem", [])
    if not raw_problems:
        raise GenerationError(f"No problems found in {path}")

    return [parse_problem(raw_problem, index) for index, raw_problem in enumerate(raw_problems)]


def parse_problem(raw_problem: dict, index: int) -> ProblemSpec:
    required_fields = ["id", "title", "module", "theorem", "submitter"]
    optional_fields = ["notes", "source", "informal_solution"]

    values: dict[str, str | None] = {}
    for field in required_fields:
        value = raw_problem.get(field)
        if not isinstance(value, str) or not value.strip():
            raise GenerationError(
                f"Problem #{index + 1} is missing required non-empty string field '{field}'"
            )
        values[field] = value.strip()

    for field in optional_fields:
        value = raw_problem.get(field)
        if value is None:
            values[field] = None
        elif isinstance(value, str):
            values[field] = value.strip() or None
        else:
            raise GenerationError(
                f"Problem '{values['id']}' has non-string optional field '{field}'"
            )

    problem_id = values["id"]
    if not isinstance(problem_id, str) or not ID_PATTERN.fullmatch(problem_id):
        raise GenerationError(
            f"Problem id '{problem_id}' is invalid. Use only letters, digits, '_' or '-'."
        )

    test_value = raw_problem.get("test", False)
    if not isinstance(test_value, bool):
        raise GenerationError(
            f"Problem '{problem_id}' has non-boolean field 'test'"
        )

    return ProblemSpec(
        id=values["id"],
        title=values["title"],
        test=test_value,
        module=values["module"],
        theorem=values["theorem"],
        submitter=values["submitter"],
        notes=values["notes"],
        source=values["source"],
        informal_solution=values["informal_solution"],
    )


def validate_problems(problems: list[ProblemSpec]) -> None:
    seen_ids: set[str] = set()
    seen_theorems: set[tuple[str, str]] = set()
    for problem in problems:
        if problem.id in seen_ids:
            raise GenerationError(f"Duplicate problem id '{problem.id}'")
        seen_ids.add(problem.id)

        theorem_key = (problem.module, problem.theorem)
        if theorem_key in seen_theorems:
            raise GenerationError(
                f"Duplicate theorem reference '{problem.module}:{problem.theorem}'"
            )
        seen_theorems.add(theorem_key)


def run(
    cmd: list[str],
    *,
    cwd: pathlib.Path,
    capture_output: bool = False,
    error_prefix: str,
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        cmd,
        cwd=cwd,
        text=True,
        capture_output=capture_output,
        check=False,
    )
    if completed.returncode != 0:
        stderr = (completed.stderr or "").strip()
        stdout = (completed.stdout or "").strip()
        details = "\n".join(part for part in [stderr, stdout] if part)
        if details:
            raise GenerationError(f"{error_prefix}:\n{details}")
        raise GenerationError(error_prefix)
    return completed


def unique_modules(problems: list[ProblemSpec]) -> list[str]:
    modules: list[str] = []
    seen: set[str] = set()
    for problem in problems:
        if problem.module not in seen:
            seen.add(problem.module)
            modules.append(problem.module)
    return modules


def build_inventory_tool(problems: list[ProblemSpec]) -> None:
    run(
        ["lake", "build", *unique_modules(problems), "eval_inventory"],
        cwd=REPO_ROOT,
        error_prefix="Failed to build Lean problem inventory tool",
    )


def build_extractor(problems: list[ProblemSpec]) -> None:
    run(
        ["lake", "build", *unique_modules(problems), "extract_theorem"],
        cwd=REPO_ROOT,
        error_prefix="Failed to build Lean theorem extractor",
    )


def extract_theorem(problem: ProblemSpec) -> ExtractedTheorem:
    binary_path = REPO_ROOT / ".lake" / "build" / "bin" / "extract_theorem"
    completed = run(
        ["lake", "env", str(binary_path), problem.module, problem.theorem],
        cwd=REPO_ROOT,
        capture_output=True,
        error_prefix=f"Lean extraction failed for '{problem.id}'",
    )
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise GenerationError(
            f"Lean extractor returned invalid JSON for '{problem.id}': {exc}"
        ) from exc

    try:
        return ExtractedTheorem(
            declaration_name=str(payload["declarationName"]),
            module=str(payload["module"]),
            source_range=(
                int(payload["sourceRange"]["startLine"]),
                int(payload["sourceRange"]["startColumn"]),
                int(payload["sourceRange"]["endLine"]),
                int(payload["sourceRange"]["endColumn"]),
            ),
            same_module_dependencies=tuple(
                str(name) for name in payload.get("sameModuleDependencies", [])
            ),
        )
    except KeyError as exc:
        raise GenerationError(
            f"Lean extractor response for '{problem.id}' is missing field {exc}"
        ) from exc


def inventory_entries(problems: list[ProblemSpec]) -> list[InventoryEntry]:
    binary_path = REPO_ROOT / ".lake" / "build" / "bin" / "eval_inventory"
    completed = run(
        ["lake", "env", str(binary_path), *unique_modules(problems)],
        cwd=REPO_ROOT,
        capture_output=True,
        error_prefix="Lean problem inventory failed",
    )
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise GenerationError(f"Problem inventory returned invalid JSON: {exc}") from exc

    entries: list[InventoryEntry] = []
    for raw_entry in payload:
        entries.append(
            InventoryEntry(
                module=str(raw_entry["module"]),
                declaration_name=str(raw_entry["declarationName"]),
                basename=str(raw_entry["basename"]),
            )
        )
    return entries


def validate_manifest_against_inventory(problems: list[ProblemSpec]) -> None:
    build_inventory_tool(problems)
    entries = inventory_entries(problems)
    by_module: dict[str, list[InventoryEntry]] = {}
    for entry in entries:
        by_module.setdefault(entry.module, []).append(entry)

    matched_declarations: set[str] = set()
    for problem in problems:
        candidates = [
            entry
            for entry in by_module.get(problem.module, [])
            if problem.theorem in {entry.basename, entry.declaration_name}
        ]
        if not candidates:
            raise GenerationError(
                f"Manifest entry '{problem.id}' does not match any @[eval_problem] theorem in "
                f"module '{problem.module}'."
            )
        if len(candidates) > 1:
            raise GenerationError(
                f"Manifest entry '{problem.id}' is ambiguous in module '{problem.module}'. "
                f"Use a fully qualified theorem name."
            )
        matched_declarations.add(candidates[0].declaration_name)

    untracked = sorted(
        entry.declaration_name
        for entry in entries
        if entry.declaration_name not in matched_declarations
    )
    if untracked:
        joined = ", ".join(untracked)
        raise GenerationError(
            "Tagged @[eval_problem] theorem(s) are missing from manifests/problems.toml: "
            f"{joined}"
        )


def validate_theorem_proof_shape(problems: list[ProblemSpec]) -> None:
    for problem in problems:
        source_path = module_source_path(problem.module)
        if not source_path.is_file():
            raise GenerationError(
                f"Source file for module '{problem.module}' not found: {source_path}"
            )
        source_text = source_path.read_text(encoding="utf-8")
        theorem_name = problem.theorem.rsplit(".", maxsplit=1)[-1]
        if not _theorem_by_pattern(theorem_name).search(source_text):
            raise GenerationError(
                f"Problem '{problem.id}' points at `theorem {theorem_name}` in "
                f"{source_path.relative_to(REPO_ROOT)}, but the declaration does not match "
                "the required `theorem <name> ... := by` shape used by the source slicer. "
                "Rewrite the proof as `:= by <tactics-or-sorry>`."
            )


def local_theorem_name(extracted: ExtractedTheorem) -> str:
    return extracted.declaration_name.rsplit(".", maxsplit=1)[-1]


def module_source_path(module_name: str) -> pathlib.Path:
    return REPO_ROOT.joinpath(*module_name.split(".")).with_suffix(".lean")


def offset_for_line_column(text: str, line: int, column: int) -> int:
    if line < 1:
        raise GenerationError(f"Invalid source line {line}")
    current_line = 1
    offset = 0
    while current_line < line:
        next_newline = text.find("\n", offset)
        if next_newline == -1:
            raise GenerationError(f"Source ended before line {line}")
        offset = next_newline + 1
        current_line += 1
    return offset + column


def extract_statement_text(problem: ProblemSpec, extracted: ExtractedTheorem) -> str:
    source_path = module_source_path(problem.module)
    if not source_path.is_file():
        raise GenerationError(f"Source file for module '{problem.module}' not found: {source_path}")
    source_text = source_path.read_text(encoding="utf-8")
    start_line, start_column, end_line, end_column = extracted.source_range
    start = offset_for_line_column(source_text, start_line, start_column)
    end = offset_for_line_column(source_text, end_line, end_column)
    declaration_text = source_text[start:end]
    theorem_name = local_theorem_name(extracted)
    match = _theorem_by_pattern(theorem_name).search(declaration_text)
    if not match:
        raise GenerationError(
            f"Could not recover theorem statement text for '{problem.id}' from {source_path}"
        )
    return match.group("body").strip()


def extract_source_text_for_range(source_text: str, source_range: tuple[int, int, int, int]) -> str:
    start_line, start_column, end_line, end_column = source_range
    start = offset_for_line_column(source_text, start_line, start_column)
    end = offset_for_line_column(source_text, end_line, end_column)
    return source_text[start:end]


def offset_range_for_source_range(source_text: str, source_range: tuple[int, int, int, int]) -> tuple[int, int]:
    start_line, start_column, end_line, end_column = source_range
    return (
        offset_for_line_column(source_text, start_line, start_column),
        offset_for_line_column(source_text, end_line, end_column),
    )


def import_prelude_length(source_text: str) -> int:
    lines = source_text.splitlines(keepends=True)
    index = 0
    consumed = 0
    while index < len(lines):
        stripped = lines[index].strip()
        if stripped.startswith("import "):
            consumed += len(lines[index])
            index += 1
            continue
        if stripped == "":
            consumed += len(lines[index])
            index += 1
            continue
        break
    return consumed


def ilean_path(module_name: str) -> pathlib.Path:
    return REPO_ROOT / ".lake" / "build" / "lib" / "lean" / pathlib.Path(*module_name.split(".")).with_suffix(".ilean")


def load_ilean_metadata(module_name: str) -> dict:
    path = ilean_path(module_name)
    if not path.is_file():
        raise GenerationError(f"Compiled metadata for module '{module_name}' not found: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise GenerationError(f"Invalid JSON in compiled metadata for module '{module_name}': {exc}") from exc


def find_top_level_end_offset(source_text: str, start: int) -> int:
    match = re.search(r"(?m)^end(?:\s+\S+)?\s*$", source_text[start:])
    if match is None:
        return len(source_text)
    return start + match.start()


def render_challenge_deps(problem: ProblemSpec, extracted: ExtractedTheorem) -> str | None:
    source_path = module_source_path(problem.module)
    if not source_path.is_file():
        raise GenerationError(f"Source file for module '{problem.module}' not found: {source_path}")

    source_text = source_path.read_text(encoding="utf-8")
    body_start = import_prelude_length(source_text)
    metadata = load_ilean_metadata(problem.module)
    keep_declarations = set(extracted.same_module_dependencies)
    if not keep_declarations:
        return None
    all_declarations = {
        str(name): value
        for name, value in metadata.get("decls", {}).items()
        if isinstance(name, str) and isinstance(value, list) and len(value) >= 4
    }

    declaration_starts: list[tuple[str, int]] = []
    for declaration_name, raw_range in all_declarations.items():
        declaration_start = offset_for_line_column(
            source_text,
            int(raw_range[0]) + 1,
            int(raw_range[1]),
        )
        declaration_starts.append((declaration_name, declaration_start))
    declaration_starts.sort(key=lambda item: item[1])

    theorem_start, theorem_end = offset_range_for_source_range(source_text, extracted.source_range)
    remove_ranges: list[tuple[int, int]] = []
    for index, (declaration_name, declaration_start) in enumerate(declaration_starts):
        if declaration_name in keep_declarations:
            continue
        if declaration_name == extracted.declaration_name:
            remove_ranges.append((theorem_start, theorem_end))
            continue

        if index + 1 < len(declaration_starts):
            next_start = declaration_starts[index + 1][1]
        else:
            next_start = find_top_level_end_offset(source_text, declaration_start)
        remove_ranges.append((declaration_start, next_start))

    remove_ranges.sort()
    pieces: list[str] = []
    cursor = body_start
    for start, end in remove_ranges:
        if end <= body_start:
            continue
        start = max(start, body_start)
        if start < cursor:
            continue
        pieces.append(source_text[cursor:start])
        cursor = end
    pieces.append(source_text[cursor:])
    challenge_deps_body = "".join(pieces).lstrip("\n")
    if challenge_deps_body and not challenge_deps_body.endswith("\n"):
        challenge_deps_body += "\n"

    return "import Mathlib\n\n" + challenge_deps_body


def extract_context_opens(problem: ProblemSpec, *, include_namespaces: bool = False) -> str:
    source_path = module_source_path(problem.module)
    if not source_path.is_file():
        raise GenerationError(f"Source file for module '{problem.module}' not found: {source_path}")
    lines = source_path.read_text(encoding="utf-8").splitlines()
    context_lines: list[str] = []
    namespace_stack: list[str] = []
    in_body = False
    for line in lines:
        stripped = line.strip()
        if not in_body:
            if stripped.startswith("import ") or stripped == "":
                continue
            in_body = True
        if stripped.startswith("@[") or re.match(
            r"^(theorem|lemma|def|abbrev|opaque|axiom|instance|class|structure)\b",
            stripped,
        ):
            break
        if stripped.startswith("namespace "):
            namespace_stack.append(stripped.split(maxsplit=1)[1].strip())
        elif re.match(r"^end\b", stripped):
            if namespace_stack:
                namespace_stack.pop()
        elif stripped.startswith("open "):
            context_lines.append(line)
    if include_namespaces and namespace_stack:
        context_lines.insert(0, "open " + ".".join(namespace_stack))
    return "\n".join(context_lines) + ("\n\n" if context_lines else "")


def explicit_binder_names(theorem_statement: str) -> list[str]:
    return re.findall(r"\(([^()\s:\[\]{}]+)\s*:", theorem_statement)


def leading_binders(theorem_statement: str) -> list[tuple[str, str]]:
    binders: list[tuple[str, str]] = []
    i = 0
    n = len(theorem_statement)
    matching = {"(": ")", "{": "}", "[": "]"}
    while i < n:
        while i < n and theorem_statement[i].isspace():
            i += 1
        if i >= n or theorem_statement[i] not in matching:
            break
        opener = theorem_statement[i]
        closer = matching[opener]
        depth = 0
        start = i
        while i < n:
            ch = theorem_statement[i]
            if ch == opener:
                depth += 1
            elif ch == closer:
                depth -= 1
                if depth == 0:
                    i += 1
                    binders.append((opener, theorem_statement[start + 1 : i - 1].strip()))
                    break
            i += 1
        else:
            break
    return binders


def binder_application_args(theorem_statement: str) -> list[str]:
    args: list[str] = []
    for opener, body in leading_binders(theorem_statement):
        name_match = re.match(r"([^()\s:\[\]{}]+)\s*:", body)
        if name_match:
            args.append(name_match.group(1))
        elif opener == "[":
            args.append("_")
        else:
            args.append("_")
    return args


def explicit_binder_application_args(theorem_statement: str) -> list[str]:
    args: list[str] = []
    for opener, body in leading_binders(theorem_statement):
        if opener != "(":
            continue
        names, sep, _type = body.partition(":")
        if not sep:
            continue
        for name in names.split():
            if name:
                args.append(name)
    return args


def render_workspace(
    problem: ProblemSpec,
    extracted: ExtractedTheorem,
    toolchain: str,
    mathlib_dependency: DependencySpec,
) -> dict[str, str]:
    theorem_name = local_theorem_name(extracted)
    theorem_statement = extract_statement_text(problem, extracted)
    solution_args = explicit_binder_application_args(theorem_statement)
    solution_exact = f"Submission.{theorem_name}"
    if solution_args:
        solution_exact += " " + " ".join(solution_args)
    challenge_deps = render_challenge_deps(problem, extracted)
    challenge_import = "import ChallengeDeps\n\n" if challenge_deps is not None else "import Mathlib\n\n"
    solution_imports = (
        "import ChallengeDeps\nimport Submission\n\n"
        if challenge_deps is not None
        else "import Mathlib\nimport Submission\n\n"
    )
    submission_imports = (
        "import ChallengeDeps\nimport Submission.Helpers\n\n"
        if challenge_deps is not None
        else "import Mathlib\nimport Submission.Helpers\n\n"
    )
    context_open_block = extract_context_opens(
        problem, include_namespaces=challenge_deps is not None
    )
    if context_open_block and not context_open_block.endswith("\n\n"):
        context_open_block += "\n"
    readme_lines = [
        f"# `{problem.id}`",
        "",
        problem.title,
        "",
        f"- Problem ID: `{problem.id}`",
        f"- Test Problem: {'yes' if problem.test else 'no'}",
        f"- Submitter: {problem.submitter}",
    ]
    if problem.notes:
        readme_lines.append(f"- Notes: {problem.notes}")
    if problem.source:
        readme_lines.append(f"- Source: {problem.source}")
    if problem.informal_solution:
        readme_lines.append(f"- Informal solution: {problem.informal_solution}")
    readme_lines.extend(
        [
            "",
            "Do not modify `Challenge.lean` or `Solution.lean`. Those files are part of the",
            "trusted benchmark and fixed by the repository.",
            "",
            "Write your solution in `Submission.lean` and any additional local modules under",
            "`Submission/`.",
            "",
            "Participants may use Mathlib freely. Any helper code not already available in",
            "Mathlib must be inlined into the submission workspace.",
            "",
            "Multi-file submissions are allowed through `Submission.lean` and additional local",
            "modules under `Submission/`.",
            "",
            "`lake test` runs comparator for this problem. The command expects a comparator",
            "binary in `PATH`, or in the `COMPARATOR_BIN` environment variable.",
        ]
    )

    config = {
        "challenge_module": "Challenge",
        "solution_module": "Solution",
        "theorem_names": [theorem_name],
        "permitted_axioms": FIXED_AXIOMS,
        "enable_nanoda": False,
    }

    files = {
        "README.md": "\n".join(readme_lines) + "\n",
        "lean-toolchain": toolchain if toolchain.endswith("\n") else toolchain + "\n",
        "lakefile.toml": (
            f'name = "{problem.id}"\n'
            + 'testDriver = "workspace_test"\n'
            + 'defaultTargets = ["Challenge", "Solution", "Submission"]\n\n'
            + "[leanOptions]\n"
            + 'autoImplicit = false\n\n'
            + "[[require]]\n"
            + f'name = "{mathlib_dependency.name}"\n'
            + f'git = "{mathlib_dependency.git}"\n'
            + f'rev = "{mathlib_dependency.rev}"\n\n'
            + (
                "[[lean_lib]]\n"
                'name = "ChallengeDeps"\n\n'
                if challenge_deps is not None
                else ""
            ) +
            "[[lean_lib]]\n"
            + 'name = "Challenge"\n\n'
            + "[[lean_lib]]\n"
            + 'name = "Solution"\n\n'
            + "[[lean_lib]]\n"
            + 'name = "Submission"\n\n'
            + "[[lean_exe]]\n"
            + 'name = "workspace_test"\n'
            + 'root = "WorkspaceTest"\n'
        ),
        "Challenge.lean": (
            challenge_import +
            f"{context_open_block}"
            f"theorem {theorem_name} {theorem_statement} := by\n"
            "  sorry\n"
        ),
        "Solution.lean": (
            solution_imports +
            f"{context_open_block}"
            f"theorem {theorem_name} {theorem_statement} := by\n"
            f"  exact {solution_exact}\n"
        ),
        "Submission.lean": (
            submission_imports +
            f"{context_open_block}"
            "namespace Submission\n\n"
            f"theorem {theorem_name} {theorem_statement} := by\n"
            "  sorry\n\n"
            "end Submission\n"
        ),
        "Submission/Helpers.lean": (
            "namespace Submission.Helpers\n\n"
            "end Submission.Helpers\n"
        ),
        "WorkspaceTest.lean": (
            "import Lean\n\n"
            "open Lean\n\n"
            "def comparatorExists (comparatorBin : String) : IO Bool := do\n"
            "  if comparatorBin.contains '/' then\n"
            "    return (← System.FilePath.pathExists comparatorBin)\n"
            "  try\n"
            "    let child ← IO.Process.spawn {\n"
            '      cmd := "sh"\n'
            '      args := #["-c", "command -v \\\"$1\\\" >/dev/null 2>&1", "sh", comparatorBin]\n'
            "    }\n"
            "    let exitCode ← child.wait\n"
            "    return exitCode == 0\n"
            "  catch _ =>\n"
            "    return false\n\n"
            "def main : IO UInt32 := do\n"
            '  let comparatorBin := (← IO.getEnv "COMPARATOR_BIN").getD "comparator"\n'
            "  if !(← comparatorExists comparatorBin) then\n"
            '    IO.eprintln s!"Failed to run comparator via `{comparatorBin}`."\n'
            '    IO.eprintln "Make sure `comparator` is installed and on your `PATH`, or set `COMPARATOR_BIN=/path/to/comparator`."\n'
            '    IO.eprintln "See the root repository README for comparator setup details, including landrun and lean4export."\n'
            "    pure 1\n"
            "  else\n"
            "    try\n"
            "      let child ← IO.Process.spawn {\n"
            '        cmd := "lake"\n'
            '        args := #["env", comparatorBin, "config.json"]\n'
            "      }\n"
            "      let exitCode ← child.wait\n"
            "      pure exitCode\n"
            "    catch err =>\n"
            '      IO.eprintln s!"Failed to run comparator via `{comparatorBin}`."\n'
            '      IO.eprintln "Make sure `comparator` is installed and on your `PATH`, or set `COMPARATOR_BIN=/path/to/comparator`."\n'
            '      IO.eprintln "See the root repository README for comparator setup details, including landrun and lean4export."\n'
            '      IO.eprintln s!"Original error: {err}"\n'
            "      pure 1\n"
        ),
        "config.json": json.dumps(config, indent=2) + "\n",
    }
    if challenge_deps is not None:
        files["ChallengeDeps.lean"] = challenge_deps
    return files


def gather_extra_paths(problem_dir: pathlib.Path) -> list[pathlib.Path]:
    extras: list[pathlib.Path] = []
    if not problem_dir.exists():
        return extras
    for path in sorted(problem_dir.rglob("*")):
        if path.is_dir():
            continue
        relative = path.relative_to(problem_dir)
        relative_text = relative.as_posix()
        first_component = relative.parts[0]
        if first_component in IGNORED_PATH_NAMES:
            continue
        if relative_text not in EXPECTED_FILES:
            extras.append(relative)
    return extras


def write_workspace(problem_dir: pathlib.Path, files: dict[str, str]) -> None:
    problem_dir.mkdir(parents=True, exist_ok=True)
    for relative_path in EXPECTED_FILES:
        if relative_path in files:
            continue
        destination = problem_dir / relative_path
        if destination.is_file():
            destination.unlink()
    for relative in gather_extra_paths(problem_dir):
        (problem_dir / relative).unlink()
    for relative_path, content in files.items():
        destination = problem_dir / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(content, encoding="utf-8")


def _display_path(path: pathlib.Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def check_workspace(problem_dir: pathlib.Path, files: dict[str, str]) -> list[str]:
    mismatches: list[str] = []
    for relative_path in EXPECTED_FILES:
        if relative_path in files:
            continue
        destination = problem_dir / relative_path
        if destination.exists():
            mismatches.append(f"unexpected {_display_path(destination)}")
    for relative_path, expected_content in files.items():
        destination = problem_dir / relative_path
        if not destination.is_file():
            mismatches.append(f"missing {_display_path(destination)}")
            continue
        actual_content = destination.read_text(encoding="utf-8")
        if actual_content != expected_content:
            mismatches.append(f"stale {_display_path(destination)}")
    for extra in gather_extra_paths(problem_dir):
        mismatches.append(f"unexpected {_display_path(problem_dir / extra)}")
    return mismatches


def sync_unknown_problem_dirs(selected_problem_ids: set[str], check: bool) -> list[str]:
    mismatches: list[str] = []
    GENERATED_ROOT.mkdir(parents=True, exist_ok=True)
    for path in sorted(GENERATED_ROOT.iterdir()):
        if path.name == "index.json":
            continue
        if not path.is_dir():
            continue
        if path.name in selected_problem_ids:
            continue
        if check:
            mismatches.append(f"unexpected generated directory {_display_path(path)}")
        else:
            shutil.rmtree(path)
    return mismatches


def write_or_check_index(index_entries: list[dict[str, str]], check: bool) -> list[str]:
    index_path = GENERATED_ROOT / "index.json"
    content = json.dumps(index_entries, indent=2) + "\n"
    if check:
        if not index_path.is_file():
            return [f"missing {_display_path(index_path)}"]
        if index_path.read_text(encoding="utf-8") != content:
            return [f"stale {_display_path(index_path)}"]
        return []
    GENERATED_ROOT.mkdir(parents=True, exist_ok=True)
    index_path.write_text(content, encoding="utf-8")
    return []


def generate(
    *,
    manifest_path: pathlib.Path,
    selected_problem_id: str | None,
    check: bool,
    extractor: Callable[[ProblemSpec], ExtractedTheorem] = extract_theorem,
) -> None:
    problems = load_manifest(manifest_path)
    validate_problems(problems)

    if selected_problem_id is not None:
        problems = [problem for problem in problems if problem.id == selected_problem_id]
        if not problems:
            raise GenerationError(f"Unknown problem id '{selected_problem_id}'")
    else:
        validate_manifest_against_inventory(problems)
        sync_mismatches = sync_unknown_problem_dirs(
            {problem.id for problem in problems},
            check=check,
        )
        if sync_mismatches:
            raise GenerationError("\n".join(sync_mismatches))

    validate_theorem_proof_shape(problems)

    toolchain = (REPO_ROOT / "lean-toolchain").read_text(encoding="utf-8")
    mathlib_dependency = load_root_mathlib_dependency()

    build_extractor(problems)

    index_entries: list[dict[str, str]] = []
    mismatches: list[str] = []
    for problem in problems:
        extracted = extractor(problem)
        files = render_workspace(problem, extracted, toolchain, mathlib_dependency)
        problem_dir = GENERATED_ROOT / problem.id
        if check:
            mismatches.extend(check_workspace(problem_dir, files))
        else:
            write_workspace(problem_dir, files)
        index_entries.append(
            {
                "id": problem.id,
                "title": problem.title,
                "test": problem.test,
                "submitter": problem.submitter,
                "module": problem.module,
                "theorem": problem.theorem,
                "generated_path": f"generated/{problem.id}",
            }
        )

    if selected_problem_id is None:
        mismatches.extend(write_or_check_index(index_entries, check))

    if mismatches:
        raise GenerationError("\n".join(mismatches))

    if check:
        print("Generated workspaces are up to date.")
    else:
        print(f"Generated {len(problems)} problem workspace(s).")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--manifest",
        default=str(DEFAULT_MANIFEST),
        help="Path to the problem manifest.",
    )
    parser.add_argument(
        "--problem",
        help="Only generate the workspace for the given problem id.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check whether generated workspaces are up to date without rewriting files.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        generate(
            manifest_path=pathlib.Path(args.manifest),
            selected_problem_id=args.problem,
            check=args.check,
        )
    except GenerationError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
