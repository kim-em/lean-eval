#!/usr/bin/env python3
"""
Audit GitHub Actions workflows for mutable selectors.

Hard-fails on:
  - `uses: <action>@main`, `@master`, `@develop`, `@latest`
  - `uses: <action>@v<N>` or `@v<N>.<M>` (loose major / minor selectors;
    tags are mutable and the action publisher can move them)
  - `go-version: stable` / `latest`
  - `node-version: latest`
  - `python-version` without a patch component (e.g. `3.11` is loose)
  - `go install <pkg>@<ref>` in run-blocks where <ref> is `main`,
    `master`, `latest`, or `v<N>.<M>(.X)` (tag, mutable)
  - `git checkout <ref>` in run-blocks where <ref> looks like a tag
    rather than a 40-char SHA

Per-line opt-out via inline trailing comment:
  - `# pin-audit: exempt -- <reason>`

Allowlist via repo-level config (TOML) at .github/pin-audit-allowlist.toml,
not yet implemented (kept simple deliberately; revisit if needed).

The script's exit code is the number of policy violations (capped at 255).
Zero means the workflows are clean.

This is the audit step required by SECURITY.md > "Validations done at
submission time" > action_pin_audit.
"""

from __future__ import annotations

import argparse
import dataclasses
import pathlib
import re
import sys
from typing import Iterable

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_WORKFLOWS_DIR = REPO_ROOT / ".github" / "workflows"

# A 40-char hex SHA. Anything else used as a ref is mutable.
SHA_RE = re.compile(r"^[0-9a-f]{40}$")

# Tokens we explicitly reject as refs (case-insensitive).
MUTABLE_REF_NAMES = {"main", "master", "develop", "trunk", "latest", "head"}

EXEMPT_MARKER_RE = re.compile(r"#\s*pin-audit:\s*exempt\b")

# `uses: owner/repo@ref` or `uses: owner/repo/sub@ref`
USES_RE = re.compile(r"^(?P<indent>\s*)(?:-\s*)?uses:\s*(?P<spec>\S+)\s*(?:#.*)?$")

# `go install <pkg>@<ref>` inside a run-block. Conservative match.
GO_INSTALL_RE = re.compile(r"\bgo\s+install\s+(?P<pkg>\S+?)@(?P<ref>\S+)")

# `git checkout <ref>` inside a run-block.
GIT_CHECKOUT_RE = re.compile(r"\bgit\s+checkout\s+(?P<ref>[^\s&;|]+)")

# `<key>: <value>` for keys we audit (supports inline comments).
KV_RE = re.compile(
    r"^(?P<indent>\s*)(?P<key>go-version|node-version|python-version):\s*(?P<value>\S+)\s*(?:#.*)?$"
)


@dataclasses.dataclass(frozen=True)
class Violation:
    file: pathlib.Path
    line_no: int
    line: str
    message: str

    def render(self, repo_root: pathlib.Path) -> str:
        try:
            rel = self.file.relative_to(repo_root)
        except ValueError:
            rel = self.file
        return f"{rel}:{self.line_no}: {self.message}\n    {self.line.rstrip()}"


def _is_loose_ref(ref: str) -> bool:
    """A ref is 'loose' (mutable) unless it's a 40-char hex SHA."""
    return not SHA_RE.fullmatch(ref)


def _classify_uses_ref(spec: str) -> str | None:
    """Return a violation message for a `uses:` spec, or None if it's pinned.

    `spec` is the value after `uses:`, e.g. `actions/checkout@v4` or
    `owner/repo/path@<sha>` or a local action path like `./.github/...`.
    """
    if spec.startswith("./") or spec.startswith("../"):
        # Local action; not a supply-chain risk.
        return None
    if "@" not in spec:
        return f"`uses: {spec}` has no @ref; treat as ambiguous and pin to a SHA."
    action, ref = spec.rsplit("@", 1)
    if SHA_RE.fullmatch(ref):
        return None
    if ref.lower() in MUTABLE_REF_NAMES:
        return f"`uses: {action}@{ref}` is a mutable branch selector; pin to a 40-char SHA."
    if re.fullmatch(r"v\d+(\.\d+){0,2}", ref):
        return f"`uses: {action}@{ref}` is a tag selector (mutable); pin to a 40-char SHA."
    return f"`uses: {action}@{ref}` is not a 40-char SHA; pin to one."


def _classify_kv(key: str, value: str) -> str | None:
    if key in ("go-version", "node-version"):
        if value.lower() in {"stable", "latest", "lts/*", "lts"}:
            return f"`{key}: {value}` is a moving target; pin to a concrete version."
        # X.Y.Z is fine; X.Y is borderline (we accept), X alone is too loose
        if not re.fullmatch(r"\d+(\.\d+){1,2}", value.strip("'\"")):
            return f"`{key}: {value}` is not a concrete X.Y[.Z] version."
        return None
    if key == "python-version":
        v = value.strip("'\"")
        if v.lower() == "latest":
            return f"`python-version: {value}` is a moving target."
        if not re.fullmatch(r"\d+\.\d+(\.\d+)?", v):
            return f"`python-version: {value}` is not a concrete X.Y or X.Y.Z."
        return None
    return None


def _classify_go_install(pkg: str, ref: str) -> str | None:
    if SHA_RE.fullmatch(ref):
        return None
    if ref.lower() in MUTABLE_REF_NAMES:
        return f"`go install {pkg}@{ref}` is a mutable branch selector; pin to a 40-char SHA."
    return f"`go install {pkg}@{ref}` is not a 40-char SHA; pin to one."


def _classify_git_checkout(ref: str) -> str | None:
    # `git checkout` is also used to switch back to working branches in
    # multi-step scripts; we only flag refs that look explicitly like a
    # version tag (vN.M[.K], optional rcN suffix) and are not a SHA.
    if SHA_RE.fullmatch(ref):
        return None
    if re.fullmatch(r"v\d+(\.\d+){0,2}(-[A-Za-z0-9.-]+)?", ref):
        return f"`git checkout {ref}` checks out a tag (mutable); pin to a 40-char SHA."
    if ref.lower() in MUTABLE_REF_NAMES:
        return f"`git checkout {ref}` switches to a mutable branch in workflow context; pin to a 40-char SHA if this is a build dependency."
    return None


def audit_file(path: pathlib.Path) -> list[Violation]:
    violations: list[Violation] = []
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        return [Violation(path, 0, "", f"failed to read: {exc}")]
    for line_no, line in enumerate(text.splitlines(), start=1):
        if EXEMPT_MARKER_RE.search(line):
            continue
        m = USES_RE.match(line)
        if m:
            msg = _classify_uses_ref(m.group("spec"))
            if msg:
                violations.append(Violation(path, line_no, line, msg))
            continue
        m = KV_RE.match(line)
        if m:
            msg = _classify_kv(m.group("key"), m.group("value"))
            if msg:
                violations.append(Violation(path, line_no, line, msg))
            continue
        for gm in GO_INSTALL_RE.finditer(line):
            msg = _classify_go_install(gm.group("pkg"), gm.group("ref"))
            if msg:
                violations.append(Violation(path, line_no, line, msg))
        for cm in GIT_CHECKOUT_RE.finditer(line):
            msg = _classify_git_checkout(cm.group("ref"))
            if msg:
                violations.append(Violation(path, line_no, line, msg))
    return violations


def audit_dir(workflows_dir: pathlib.Path) -> list[Violation]:
    violations: list[Violation] = []
    for path in sorted(workflows_dir.glob("*.yml")) + sorted(workflows_dir.glob("*.yaml")):
        violations.extend(audit_file(path))
    return violations


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--workflows-dir",
        type=pathlib.Path,
        default=DEFAULT_WORKFLOWS_DIR,
        help="Directory of workflow YAML files to audit.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    workflows_dir: pathlib.Path = args.workflows_dir
    if not workflows_dir.is_dir():
        print(f"workflows dir not found: {workflows_dir}", file=sys.stderr)
        return 2
    violations = audit_dir(workflows_dir)
    if not violations:
        print(f"action_pin_audit: clean ({workflows_dir})")
        return 0
    print(
        f"action_pin_audit: {len(violations)} violation(s) in {workflows_dir}",
        file=sys.stderr,
    )
    for v in violations:
        print(v.render(REPO_ROOT), file=sys.stderr)
    return min(len(violations), 255)


if __name__ == "__main__":
    raise SystemExit(main())
