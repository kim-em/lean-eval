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
    "holes.json",
}
IGNORED_PATH_NAMES = {".lake", "build", ".cache", "lake-manifest.json"}


_WORKSPACE_TEST_LEAN = (
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
)


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
    holes: tuple[str, ...]
    submitter: str
    notes: str | None = None
    source: str | None = None
    informal_solution: str | None = None

    @property
    def is_multi_hole(self) -> bool:
        return len(self.holes) != 1


@dataclass(frozen=True)
class ExtractedTheorem:
    declaration_name: str
    module: str
    source_range: tuple[int, int, int, int]
    same_module_dependencies: tuple[str, ...]
    kind: str  # "theorem", "def", or "instance"


@dataclass(frozen=True)
class DependencySpec:
    name: str
    git: str
    rev: str


def _theorem_pattern(theorem_name: str) -> re.Pattern[str]:
    return re.compile(
        rf"(?:^|\s)(?:theorem|opaque|def|instance)\s+{re.escape(theorem_name)}\b",
        re.DOTALL,
    )


@dataclass(frozen=True)
class InventoryEntry:
    module: str
    declaration_name: str
    basename: str
    kind: str  # "theorem", "def", or "instance"


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
    required_fields = ["id", "title", "module", "submitter"]
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

    holes_value = raw_problem.get("holes")
    if not isinstance(holes_value, list) or not holes_value:
        raise GenerationError(
            f"Problem '{problem_id}' must give 'holes' as a non-empty array of strings."
        )
    holes_list: list[str] = []
    for entry in holes_value:
        if not isinstance(entry, str) or not entry.strip():
            raise GenerationError(
                f"Problem '{problem_id}' has an empty or non-string entry in 'holes'."
            )
        holes_list.append(entry.strip())
    if len(set(holes_list)) != len(holes_list):
        raise GenerationError(
            f"Problem '{problem_id}' has duplicate entries in 'holes'."
        )
    holes = tuple(holes_list)

    return ProblemSpec(
        id=values["id"],
        title=values["title"],
        test=test_value,
        module=values["module"],
        holes=holes,
        submitter=values["submitter"],
        notes=values["notes"],
        source=values["source"],
        informal_solution=values["informal_solution"],
    )


def validate_problems(problems: list[ProblemSpec]) -> None:
    seen_ids: set[str] = set()
    seen_holes: set[tuple[str, str]] = set()
    for problem in problems:
        if problem.id in seen_ids:
            raise GenerationError(f"Duplicate problem id '{problem.id}'")
        seen_ids.add(problem.id)

        for hole in problem.holes:
            hole_key = (problem.module, hole)
            if hole_key in seen_holes:
                raise GenerationError(
                    f"Duplicate hole reference '{problem.module}:{hole}'"
                )
            seen_holes.add(hole_key)


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


def extract_one(problem: ProblemSpec, hole: str) -> ExtractedTheorem:
    binary_path = REPO_ROOT / ".lake" / "build" / "bin" / "extract_theorem"
    completed = run(
        ["lake", "env", str(binary_path), problem.module, hole],
        cwd=REPO_ROOT,
        capture_output=True,
        error_prefix=f"Lean extraction failed for '{problem.id}' hole '{hole}'",
    )
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise GenerationError(
            f"Lean extractor returned invalid JSON for '{problem.id}' hole '{hole}': {exc}"
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
            kind=str(payload["kind"]),
        )
    except KeyError as exc:
        raise GenerationError(
            f"Lean extractor response for '{problem.id}' hole '{hole}' is missing field {exc}"
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
                kind=str(raw_entry["kind"]),
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
        for hole in problem.holes:
            candidates = [
                entry
                for entry in by_module.get(problem.module, [])
                if hole in {entry.basename, entry.declaration_name}
            ]
            if not candidates:
                raise GenerationError(
                    f"Manifest entry '{problem.id}' references hole '{hole}' which has no "
                    f"@[eval_problem] declaration in module '{problem.module}'."
                )
            if len(candidates) > 1:
                raise GenerationError(
                    f"Manifest entry '{problem.id}' hole '{hole}' is ambiguous in module "
                    f"'{problem.module}'. Use a fully qualified name."
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
            "Tagged @[eval_problem] declaration(s) are missing from manifests/problems.toml: "
            f"{joined}"
        )


def validate_hole_shape(problems: list[ProblemSpec]) -> None:
    """Sanity-check that each manifest hole is declared as a top-level
    theorem/def/instance in its source module. Type-correctness is enforced
    by `validate_manifest_against_inventory` (which builds the source);
    this check is just for early failure with a clear message when a
    manifest entry has a typo'd name."""
    for problem in problems:
        source_path = module_source_path(problem.module)
        if not source_path.is_file():
            raise GenerationError(
                f"Source file for module '{problem.module}' not found: {source_path}"
            )
        source_text = source_path.read_text(encoding="utf-8")
        for hole in problem.holes:
            basename = hole.rsplit(".", maxsplit=1)[-1]
            if not _theorem_pattern(basename).search(source_text):
                raise GenerationError(
                    f"Problem '{problem.id}' lists hole '{basename}' which is not declared "
                    f"as a top-level theorem/def/instance in {source_path.relative_to(REPO_ROOT)}."
                )


def local_theorem_name(extracted: ExtractedTheorem) -> str:
    return extracted.declaration_name.rsplit(".", maxsplit=1)[-1]


def module_source_path(module_name: str) -> pathlib.Path:
    return REPO_ROOT.joinpath(*module_name.split(".")).with_suffix(".lean")


def source_imports(source_text: str) -> list[str]:
    imports: list[str] = []
    for raw in source_text.splitlines():
        stripped = raw.strip()
        if stripped.startswith("import "):
            imports.append(stripped.split(maxsplit=1)[1])
    return imports


def repo_local_import_modules(module_name: str, seen: set[str] | None = None) -> list[str]:
    if seen is None:
        seen = set()
    source_path = module_source_path(module_name)
    if not source_path.is_file():
        return []
    source_text = source_path.read_text(encoding="utf-8")
    modules: list[str] = []
    for imported in source_imports(source_text):
        if imported.startswith("Mathlib.") or imported == "Mathlib":
            continue
        if imported.startswith("EvalTools."):
            continue
        if imported == module_name or imported in seen:
            continue
        imported_path = module_source_path(imported)
        if not imported_path.is_file():
            continue
        seen.add(imported)
        modules.extend(repo_local_import_modules(imported, seen))
        modules.append(imported)
    return modules


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
    # Find the theorem header to locate the start of the body.
    header = re.search(
        rf"(?:^|\s)theorem\s+{re.escape(theorem_name)}\b",
        declaration_text,
        re.DOTALL,
    )
    if not header:
        raise GenerationError(
            f"Could not recover theorem statement text for '{problem.id}' from {source_path}"
        )
    # Use rfind to locate the *last* `:= by` in the declaration text.
    # This handles theorems whose type contains nested `haveI ... := by`
    # clauses: the outer proof marker is always the last one.
    last_by = declaration_text.rfind(":= by")
    if last_by == -1:
        raise GenerationError(
            f"Could not recover theorem statement text for '{problem.id}' from {source_path}"
        )
    return declaration_text[header.end():last_by].strip()


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


def render_challenge_deps(
    problem: ProblemSpec,
    extracted: ExtractedTheorem,
    local_imports: list[str] | None = None,
) -> str | None:
    source_path = module_source_path(problem.module)
    if not source_path.is_file():
        raise GenerationError(f"Source file for module '{problem.module}' not found: {source_path}")

    source_text = source_path.read_text(encoding="utf-8")
    challenge_deps_parts: list[str] = []

    if local_imports is None:
        local_imports = repo_local_import_modules(problem.module)

    for imported_module in local_imports:
        imported_path = module_source_path(imported_module)
        imported_text = imported_path.read_text(encoding="utf-8")
        imported_body = _strip_problem_markers(imported_text[import_prelude_length(imported_text):]).lstrip("\n")
        if imported_body and not imported_body.endswith("\n"):
            imported_body += "\n"
        if imported_body:
            challenge_deps_parts.append(imported_body)

    metadata = load_ilean_metadata(problem.module)
    keep_declarations = set(extracted.same_module_dependencies)
    if keep_declarations:
        body_start = import_prelude_length(source_text)
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
        if challenge_deps_body:
            challenge_deps_parts.append(challenge_deps_body)

    if not challenge_deps_parts:
        return None

    return "import Mathlib\n\n" + "\n".join(part.rstrip("\n") for part in challenge_deps_parts) + "\n"


def extract_context_opens(
    problem: ProblemSpec,
    extracted: ExtractedTheorem | None = None,
    *,
    include_namespaces: bool = False,
) -> str:
    source_path = module_source_path(problem.module)
    if not source_path.is_file():
        raise GenerationError(f"Source file for module '{problem.module}' not found: {source_path}")
    lines = source_path.read_text(encoding="utf-8").splitlines()
    target_line = extracted.source_range[0] if extracted is not None else None
    namespace_stack: list[str] = []
    # `open` directives encountered, partitioned per namespace nesting level.
    # Index 0 is top-level; each `namespace` push adds a new layer that is
    # popped (and its scoped opens discarded) when the matching `end` runs.
    open_layers: list[list[str]] = [[]]
    in_body = False
    for index, line in enumerate(lines, start=1):
        if target_line is not None and index >= target_line:
            break
        stripped = line.strip()
        if not in_body:
            if stripped.startswith("import ") or stripped == "":
                continue
            in_body = True
        if target_line is None and (
            stripped.startswith("@[")
            or re.match(
                r"^(theorem|lemma|def|abbrev|opaque|axiom|instance|class|structure)\b",
                stripped,
            )
        ):
            break
        if stripped.startswith("namespace "):
            namespace_stack.append(stripped.split(maxsplit=1)[1].strip())
            open_layers.append([])
        elif re.match(r"^end\b", stripped):
            if namespace_stack:
                namespace_stack.pop()
                open_layers.pop()
        elif stripped.startswith("open "):
            open_layers[-1].append(line)
    context_lines = [line for layer in open_layers for line in layer]
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


def build_holes_metadata(
    problem: ProblemSpec,
    extracteds: list[ExtractedTheorem],
) -> str:
    """Build the JSON content for `generated/<id>/holes.json`.

    Captures, per `@[eval_problem]` hole, the fully-qualified declaration name,
    its short basename, its kind (`theorem` / `def` / `instance` / `opaque`),
    and the trimmed source body (with the `@[eval_problem]` attribute stripped,
    matching what ends up in `Challenge.lean`). Order matches the manifest's
    `holes = [...]`. Downstream consumers (e.g. the leaderboard site) read this
    instead of re-parsing source.
    """
    source_path = module_source_path(problem.module)
    if not source_path.is_file():
        raise GenerationError(
            f"Source file for module '{problem.module}' not found: {source_path}"
        )
    source_text = source_path.read_text(encoding="utf-8")
    holes_payload: list[dict[str, str]] = []
    for extracted in extracteds:
        body = extract_source_text_for_range(source_text, extracted.source_range)
        body = _strip_problem_markers(body).strip()
        holes_payload.append({
            "name": extracted.declaration_name,
            "basename": local_theorem_name(extracted),
            "kind": extracted.kind,
            "body": body,
        })
    payload = {
        "id": problem.id,
        "module": problem.module,
        "holes": holes_payload,
    }
    return json.dumps(payload, indent=2) + "\n"


def render_workspace(
    problem: ProblemSpec,
    extracteds: list[ExtractedTheorem],
    toolchain: str,
    mathlib_dependency: DependencySpec,
) -> dict[str, str]:
    """Generate the comparator workspace files for one problem.

    Two code paths:
    - Legacy single-theorem path (one hole, kind="theorem"): preserves the
      historical layout with `ChallengeDeps.lean` (for same-module dependencies)
      and a sliced `theorem ...` statement in `Challenge.lean`. All existing
      single-theorem problems take this path, so byte-identical regeneration
      is preserved.
    - Multi-hole path (defs / instances / multiple holes): copies the entire
      source module verbatim into `Challenge.lean` with `@[eval_problem]`
      attributes stripped, and emits a thin `Solution.lean` whose holes
      delegate to `Submission`. No `ChallengeDeps.lean`.
    """
    use_multi_hole = problem.is_multi_hole or extracteds[0].kind != "theorem"
    if use_multi_hole:
        files = _render_workspace_multi_hole(
            problem, extracteds, toolchain, mathlib_dependency
        )
        files["holes.json"] = build_holes_metadata(problem, extracteds)
        return files
    [extracted] = extracteds
    theorem_name = local_theorem_name(extracted)
    theorem_statement = extract_statement_text(problem, extracted)
    solution_args = explicit_binder_application_args(theorem_statement)
    solution_exact = f"Submission.{theorem_name}"
    if solution_args:
        solution_exact += " " + " ".join(solution_args)
    local_imports = repo_local_import_modules(problem.module)
    challenge_deps = render_challenge_deps(problem, extracted, local_imports)
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
        problem,
        extracted,
        include_namespaces=(challenge_deps is not None or bool(local_imports)),
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
        "WorkspaceTest.lean": _WORKSPACE_TEST_LEAN,
        "config.json": json.dumps(config, indent=2) + "\n",
    }
    if challenge_deps is not None:
        files["ChallengeDeps.lean"] = challenge_deps
    files["holes.json"] = build_holes_metadata(problem, extracteds)
    return files


# Lines that appear in source modules to mark eval-problem holes; these get
# stripped from the generated `Challenge.lean` so that submitters do not see
# (or accidentally rely on) the `@[eval_problem]` attribute machinery.
_EVAL_PROBLEM_ATTR_RE = re.compile(r"^\s*@\[eval_problem\]\s*\n", re.MULTILINE)
_EVAL_TOOLS_IMPORT_RE = re.compile(r"^\s*import\s+EvalTools\.Markers\s*\n", re.MULTILINE)


def _strip_problem_markers(source_text: str) -> str:
    """Remove `@[eval_problem]` attributes and the `EvalTools.Markers` import
    from source text destined for the generated `Challenge.lean`. The marker
    machinery exists only on the trusted side and must not leak into a problem
    workspace (which has no `EvalTools` dependency)."""
    text = _EVAL_PROBLEM_ATTR_RE.sub("", source_text)
    text = _EVAL_TOOLS_IMPORT_RE.sub("", text)
    return text


def _scan_header(lines: list[str]) -> tuple[int, int]:
    """Walk top-of-file lines and classify each as part of the file header
    (imports, blank lines, line comments `--`, block comments `/- ... -/`)
    versus the body. Returns `(insert_after_imports, body_start)` line indices.

    `insert_after_imports` is the index where a new `import` line should be
    inserted (i.e. just after the last existing import; falls back to 0 if
    there are no imports). `body_start` is the index of the first body line."""
    in_block_comment = False
    last_import_idx = -1
    body_start = len(lines)
    for idx, raw in enumerate(lines):
        stripped = raw.strip()
        if in_block_comment:
            if "-/" in stripped:
                in_block_comment = False
            continue
        if stripped == "":
            continue
        if stripped.startswith("--"):
            continue
        if stripped.startswith("/-"):
            if "-/" not in stripped[2:]:
                in_block_comment = True
            continue
        if stripped.startswith("import "):
            last_import_idx = idx
            continue
        body_start = idx
        break
    insert_after_imports = last_import_idx + 1 if last_import_idx >= 0 else 0
    return insert_after_imports, body_start


def _inject_after_imports(source_text: str, line: str) -> str:
    """Insert `line` (must end in a newline) just after the trailing `import`
    line at the top of `source_text`. If there are no imports we prepend
    `import Mathlib` followed by `line`."""
    lines = source_text.splitlines(keepends=True)
    insert_at, _ = _scan_header(lines)
    if insert_at == 0 and not any(l.lstrip().startswith("import ") for l in lines):
        return "import Mathlib\n" + line + source_text
    return "".join(lines[:insert_at]) + line + "".join(lines[insert_at:])


_TOP_LEVEL_NAMESPACE_RE = re.compile(r"^namespace\s+([A-Za-z_][\w.]*)")
_END_NAMESPACE_RE = re.compile(r"^end\s+([A-Za-z_][\w.]*)")


def _top_level_namespaces(body: str, user_namespace: str) -> list[str]:
    """Return the names of top-level (depth-0) `namespace X` declarations in
    `body` to `open` after `namespace Submission`, preserving source order
    and removing duplicates. We exclude the user-declared namespace
    (`user_namespace`, typically the source module's last path component)
    because it is freshly created by the source — `open`ing it before the
    `namespace user_namespace` line would fail with "unknown namespace".
    Top-level namespaces that the source merely re-enters (e.g. Mathlib's
    `AlgebraicGeometry`) DO need to be `open`ed, otherwise unqualified
    references inside (e.g. `Spec`) won't resolve once we wrap the body in
    `namespace Submission`."""
    by_order: list[str] = []
    seen: set[str] = set()
    depth = 0
    for raw in body.splitlines():
        if raw.lstrip().startswith("--"):
            continue
        m = _TOP_LEVEL_NAMESPACE_RE.match(raw)
        if m:
            name = m.group(1)
            if depth == 0 and name != user_namespace and name not in seen:
                by_order.append(name)
                seen.add(name)
            depth += 1
            continue
        if _END_NAMESPACE_RE.match(raw):
            depth -= 1
    return by_order


def _wrap_body_in_submission_namespace(source_text: str, user_namespace: str) -> str:
    """Wrap everything after the source's import block in
    `namespace Submission ... end Submission`. The Submission namespace lives
    OUTSIDE any namespaces declared in the source, so a hole declared in
    `namespace JacobianChallenge` becomes `Submission.JacobianChallenge.X`.

    We also `open` every top-level namespace declared in the source so that
    references inside (e.g. `Spec` inside `namespace AlgebraicGeometry`) keep
    resolving — without the `open`, the body's `namespace AlgebraicGeometry`
    would land in `Submission.AlgebraicGeometry`, which doesn't have `Spec`."""
    lines = source_text.splitlines(keepends=True)
    _, body_start = _scan_header(lines)
    if body_start >= len(lines):
        return source_text
    head = "".join(lines[:body_start])
    body = "".join(lines[body_start:])
    if not body.endswith("\n"):
        body += "\n"
    opens = "".join(f"open {ns}\n" for ns in _top_level_namespaces(body, user_namespace))
    return head + "\nnamespace Submission\n\n" + opens + body + "\nend Submission\n"


def _hole_decl_signature(decl_text: str, basename: str) -> str:
    """Strip the body off a sliced hole declaration so callers can append
    their own body. `decl_text` is the source slice of the form

        @[some_attr] def basename (args) : Type := <body>

    or any other top-level form ending in `:= ...`. Returns the prefix up to
    and including `:=`.
    """
    # Drop attributes (already stripped for Challenge but not necessarily
    # for our hole-by-hole slicing).
    text = _EVAL_PROBLEM_ATTR_RE.sub("", decl_text).strip()
    # Find the LAST `:=` at top level. The declaration body is everything after.
    # We trust that hole signatures don't contain `:=` (no `let ... :=` in a
    # type, no anonymous constructors with `:=`). Holes' bodies are `sorry`
    # so this is safe for the source files we generate from.
    marker = ":="
    idx = text.rfind(marker)
    if idx < 0:
        raise GenerationError(
            f"Hole '{basename}' declaration has no `:=` to split: {text!r}"
        )
    prefix = text[:idx].rstrip()
    return prefix + " := "


def _render_workspace_multi_hole(
    problem: ProblemSpec,
    extracteds: list[ExtractedTheorem],
    toolchain: str,
    mathlib_dependency: DependencySpec,
) -> dict[str, str]:
    """Multi-hole rendering keeps the source's `variable`/`open`/`namespace`
    structure intact so each hole's signature still type-checks. Three files
    are produced from the same source, with body rewrites:

    - `Challenge.lean`: source verbatim minus `@[eval_problem]` markers; all
      hole bodies stay as `sorry`.
    - `Solution.lean`: source verbatim with each hole's body rewritten to
      `Submission.<full-namespaced-name>`. Comparator compares Challenge and
      Solution by qualified hole name; both files preserve the source's
      namespace structure so the names match.
    - `Submission.lean`: source verbatim wrapped in `namespace Submission`,
      with hole bodies left as `sorry` for the participant to fill in.
      Submission's holes therefore live at `Submission.<full-namespaced-name>`.
    """
    source_path = module_source_path(problem.module)
    if not source_path.is_file():
        raise GenerationError(
            f"Source file for module '{problem.module}' not found: {source_path}"
        )
    source_text = source_path.read_text(encoding="utf-8")

    # Sort holes by start position so we can splice into the source text in a
    # single forward pass (then iterate in reverse when applying replacements
    # so earlier offsets stay valid).
    holes_with_ranges = []
    for extracted in extracteds:
        full_name = extracted.declaration_name
        start, end = offset_range_for_source_range(source_text, extracted.source_range)
        holes_with_ranges.append((start, end, full_name, extracted.kind))
    holes_with_ranges.sort()

    # Split hole names into theorem_names vs definition_names per comparator's
    # config schema. Both `def` and `instance` go in `definition_names`.
    theorem_names: list[str] = []
    definition_names: list[str] = []
    for _start, _end, full_name, kind in holes_with_ranges:
        if kind == "theorem":
            theorem_names.append(full_name)
        else:
            definition_names.append(full_name)

    challenge_body = _strip_problem_markers(source_text)
    if not challenge_body.lstrip().startswith("import "):
        challenge_body = "import Mathlib\n\n" + challenge_body

    # Solution.lean: same as source, but each hole's body is replaced by
    # `Submission.<full_name> <explicit-args>`. We splice replacements into
    # the source from back to front so earlier offsets remain valid.
    # Explicit args from the decl's leading binders are applied so the
    # delegating call has the right type at the body position; implicit
    # and instance args are inferred by Lean.
    solution_text = source_text
    for start, end, full_name, kind in reversed(holes_with_ranges):
        decl_text = source_text[start:end]
        basename = full_name.rsplit(".", maxsplit=1)[-1]
        signature = _hole_decl_signature(decl_text, basename)
        # Make Solution-side `def`/`instance` holes reducible so later decls in
        # the same Solution.lean (e.g. a theorem hole that mentions a def hole
        # in its statement) can defeq-unify their references with the
        # corresponding `Submission.X` term that the theorem hole's body
        # delegates to. Inject `@[reducible]` immediately before the
        # declaration keyword so it sits AFTER the doc comment (Lean rejects
        # `@[attr] /-- doc -/ def`).
        if kind != "theorem":
            keyword_pos = re.search(
                rf"\b(?:def|instance|abbrev)\s+{re.escape(basename)}\b",
                signature,
            )
            if keyword_pos is None:
                raise GenerationError(
                    f"Could not anchor `@[reducible]` injection in signature for hole '{full_name}'."
                )
            signature = (
                signature[: keyword_pos.start()]
                + "@[reducible] "
                + signature[keyword_pos.start() :]
            )
        # Find the part of the decl text BETWEEN the basename and `:=`, which
        # is the binder/return-type slice; pass it to the existing argument
        # extractor.
        # Anchor to the actual declaration keyword (`def`/`instance`/`theorem`)
        # followed by the basename — otherwise an earlier `/-- doc comment that
        # mentions {basename} -/` would steal the match.
        keyword_match = re.search(
            rf"\b(?:def|instance|theorem|opaque|lemma|abbrev|class|example)\s+{re.escape(basename)}\b",
            decl_text,
        )
        if keyword_match is None:
            raise GenerationError(
                f"Could not locate basename '{basename}' in source decl for hole '{full_name}'."
            )
        between = decl_text[keyword_match.end():]
        last_eq = between.rfind(":=")
        if last_eq < 0:
            raise GenerationError(
                f"Source decl for hole '{full_name}' has no `:=` body marker."
            )
        statement = between[:last_eq]
        explicit_args = explicit_binder_application_args(statement)
        applied = f"Submission.{full_name}"
        if explicit_args:
            applied += " " + " ".join(explicit_args)
        new_decl = signature + applied
        solution_text = solution_text[:start] + new_decl + solution_text[end:]
    solution_body = _strip_problem_markers(solution_text)
    # Solution must `import Submission` (after the source's other imports) so
    # that references to `Submission.X` resolve.
    solution_body = _inject_after_imports(solution_body, "import Submission\n")

    # Submission.lean: source verbatim wrapped in `namespace Submission`. The
    # source's own imports stay at the top (above the namespace); we add
    # `import Submission.Helpers` for participant convenience.
    submission_text = _strip_problem_markers(source_text)
    submission_text = _inject_after_imports(submission_text, "import Submission.Helpers\n")
    submission_body = _wrap_body_in_submission_namespace(
        submission_text, problem.module.rsplit(".", maxsplit=1)[-1]
    )

    readme_lines = [
        f"# `{problem.id}`",
        "",
        problem.title,
        "",
        f"- Problem ID: `{problem.id}`",
        f"- Test Problem: {'yes' if problem.test else 'no'}",
        f"- Submitter: {problem.submitter}",
        f"- Holes ({len(extracteds)}): "
        + ", ".join(f"`{e.declaration_name}` ({e.kind})" for e in extracteds),
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
            "This is a multi-hole problem: the challenge declares multiple `def`s,",
            "`instance`s, and/or `theorem`s as `sorry`. Fill all of them in",
            "`Submission.lean` (under `namespace Submission`) for comparator to accept",
            "your solution.",
            "",
            "Participants may use Mathlib freely. Any helper code not already available in",
            "Mathlib must be inlined into the submission workspace.",
            "",
            "`lake test` runs comparator for this problem. The command expects a comparator",
            "binary in `PATH`, or in the `COMPARATOR_BIN` environment variable.",
        ]
    )

    config: dict[str, object] = {
        "challenge_module": "Challenge",
        "solution_module": "Solution",
        "theorem_names": theorem_names,
        "permitted_axioms": FIXED_AXIOMS,
        "enable_nanoda": False,
    }
    if definition_names:
        config["definition_names"] = definition_names

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
            + "[[lean_lib]]\n"
            + 'name = "Challenge"\n\n'
            + "[[lean_lib]]\n"
            + 'name = "Solution"\n\n'
            + "[[lean_lib]]\n"
            + 'name = "Submission"\n\n'
            + "[[lean_exe]]\n"
            + 'name = "workspace_test"\n'
            + 'root = "WorkspaceTest"\n'
        ),
        "Challenge.lean": challenge_body if challenge_body.endswith("\n") else challenge_body + "\n",
        "Solution.lean": solution_body,
        "Submission.lean": submission_body,
        "Submission/Helpers.lean": (
            "namespace Submission.Helpers\n\n"
            "end Submission.Helpers\n"
        ),
        "WorkspaceTest.lean": _WORKSPACE_TEST_LEAN,
        "config.json": json.dumps(config, indent=2) + "\n",
    }
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
    extractor: Callable[[ProblemSpec, str], ExtractedTheorem] = extract_one,
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

    validate_hole_shape(problems)

    toolchain = (REPO_ROOT / "lean-toolchain").read_text(encoding="utf-8")
    mathlib_dependency = load_root_mathlib_dependency()

    build_extractor(problems)

    index_entries: list[dict[str, object]] = []
    mismatches: list[str] = []
    for problem in problems:
        extracteds = [extractor(problem, hole) for hole in problem.holes]
        files = render_workspace(problem, extracteds, toolchain, mathlib_dependency)
        problem_dir = GENERATED_ROOT / problem.id
        if check:
            mismatches.extend(check_workspace(problem_dir, files))
        else:
            write_workspace(problem_dir, files)
        index_entries.append({
            "id": problem.id,
            "title": problem.title,
            "test": problem.test,
            "submitter": problem.submitter,
            "module": problem.module,
            "holes": list(problem.holes),
            "generated_path": f"generated/{problem.id}",
        })

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
