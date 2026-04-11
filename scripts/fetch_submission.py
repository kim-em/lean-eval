#!/usr/bin/env python3
"""
Fetch a submission for the lean-eval benchmark.

Parses an issue-event payload to extract the submitter's URL and model,
normalizes the URL, resolves it to a concrete commit or gist revision,
clones the content to a local directory, and emits frozen metadata for
downstream workflow jobs.

This script is the sole owner of issue-body parsing in the submission
workflow; downstream jobs must only consume metadata.json, never
re-parse the issue body.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import subprocess
import sys
import tarfile
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Literal


SHA_RE = re.compile(r"^[0-9a-f]{40}$")
OWNER_RE = r"[A-Za-z0-9][A-Za-z0-9-]*"
REPO_RE = r"[A-Za-z0-9._-]+"
GIST_USER_RE = r"[A-Za-z0-9-]+"
GIST_ID_RE = r"[0-9a-f]+"
REF_RE = r"[A-Za-z0-9._/-]+"


class FetchError(Exception):
    """Raised for any submission-fetch failure. Message is user-facing."""


@dataclass(frozen=True)
class SourceDescriptor:
    kind: Literal["github_repo", "gist"]
    owner: str
    name: str
    ref: str | None


def parse_issue_body(body_text: str) -> dict[str, str]:
    """Extract source_url and model from a GitHub Issue Form's rendered body.

    Issue Forms render as markdown with section headers like
    `### Submission URL\\n\\n<value>\\n\\n### Model\\n\\n<value>`.
    Missing fields raise FetchError.
    """
    fields = {}
    for field_key, heading in (("source_url", "Submission URL"), ("model", "Model")):
        pattern = re.compile(
            rf"^###\s+{re.escape(heading)}\s*\n+(?P<value>.+?)(?=\n+###\s|\Z)",
            re.MULTILINE | re.DOTALL,
        )
        match = pattern.search(body_text)
        if match is None:
            raise FetchError(
                f"Could not find `{heading}` section in issue body. "
                "Make sure you submitted via the `Submit benchmark solution` Issue Form."
            )
        value = match.group("value").strip()
        if not value or value.startswith("_No response_"):
            raise FetchError(f"`{heading}` field is empty.")
        fields[field_key] = value
    return fields


def parse_source_url(url: str) -> SourceDescriptor:
    """Normalize and validate a submission URL.

    Raises FetchError with a user-friendly message on any reject.
    """
    url = url.strip()
    if "?" in url or "#" in url:
        raise FetchError(
            f"Submission URL must not contain `?` or `#`: {url!r}. "
            "Provide a clean URL without query strings or fragments."
        )
    if not url.startswith("https://"):
        raise FetchError(
            f"Submission URL must use https://: {url!r}. "
            "Accepted forms: https://github.com/owner/repo, "
            "https://github.com/owner/repo/tree/<sha>, "
            "https://github.com/owner/repo/commit/<sha>, "
            "https://gist.github.com/user/<id>."
        )
    rest = url[len("https://") :]
    if rest.startswith("github.com/"):
        return _parse_github_repo_url(rest[len("github.com/") :], url)
    if rest.startswith("gist.github.com/"):
        return _parse_gist_url(rest[len("gist.github.com/") :], url)
    raise FetchError(
        f"Unsupported host in submission URL: {url!r}. "
        "Only github.com and gist.github.com are accepted."
    )


def _parse_github_repo_url(path: str, original: str) -> SourceDescriptor:
    path = path.rstrip("/")
    if path.endswith(".git"):
        path = path[: -len(".git")]
    root_match = re.fullmatch(rf"(?P<owner>{OWNER_RE})/(?P<repo>{REPO_RE})", path)
    if root_match is not None:
        return SourceDescriptor(
            kind="github_repo",
            owner=root_match.group("owner"),
            name=root_match.group("repo"),
            ref=None,
        )
    tree_match = re.fullmatch(
        rf"(?P<owner>{OWNER_RE})/(?P<repo>{REPO_RE})/(?:tree|commit)/(?P<ref>{REF_RE})",
        path,
    )
    if tree_match is not None:
        return SourceDescriptor(
            kind="github_repo",
            owner=tree_match.group("owner"),
            name=tree_match.group("repo"),
            ref=tree_match.group("ref"),
        )
    raise FetchError(
        f"GitHub URL has unsupported shape: {original!r}. "
        "Accepted forms: /owner/repo, /owner/repo/tree/<ref>, "
        "/owner/repo/commit/<sha>."
    )


def _parse_gist_url(path: str, original: str) -> SourceDescriptor:
    path = path.rstrip("/")
    if path.endswith(".git"):
        path = path[: -len(".git")]
    bare_match = re.fullmatch(
        rf"(?P<user>{GIST_USER_RE})/(?P<gid>{GIST_ID_RE})",
        path,
    )
    if bare_match is not None:
        return SourceDescriptor(
            kind="gist",
            owner=bare_match.group("user"),
            name=bare_match.group("gid"),
            ref=None,
        )
    rev_match = re.fullmatch(
        rf"(?P<user>{GIST_USER_RE})/(?P<gid>{GIST_ID_RE})/(?P<rev>{GIST_ID_RE})",
        path,
    )
    if rev_match is not None:
        return SourceDescriptor(
            kind="gist",
            owner=rev_match.group("user"),
            name=rev_match.group("gid"),
            ref=rev_match.group("rev"),
        )
    raise FetchError(
        f"Gist URL has unsupported shape: {original!r}. "
        "Accepted forms: https://gist.github.com/user/<id> or "
        "https://gist.github.com/user/<id>/<revision>."
    )


def _api_get(url: str, token: str | None) -> dict:
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    req.add_header("User-Agent", "lean-eval-submission-fetcher")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise FetchError(
            f"GitHub API returned {exc.code} for {url}. "
            "If this is a private repository, install the `lean-eval-bot` GitHub App on it."
        ) from exc
    except urllib.error.URLError as exc:
        raise FetchError(f"Failed to reach GitHub API at {url}: {exc.reason}") from exc


def resolve_repo_visibility(
    descriptor: SourceDescriptor, token: str | None
) -> bool:
    """Return True if the content is public, False if private/secret.

    Secret gists are treated as private and rejected by the caller.
    """
    if descriptor.kind == "github_repo":
        data = _api_get(
            f"https://api.github.com/repos/{descriptor.owner}/{descriptor.name}",
            token,
        )
        if not isinstance(data.get("private"), bool):
            raise FetchError(
                f"GitHub API response for {descriptor.owner}/{descriptor.name} "
                "did not include a boolean `private` field."
            )
        return not data["private"]
    if descriptor.kind == "gist":
        data = _api_get(
            f"https://api.github.com/gists/{descriptor.name}",
            token,
        )
        if not isinstance(data.get("public"), bool):
            raise FetchError(
                f"GitHub API response for gist {descriptor.name} "
                "did not include a boolean `public` field."
            )
        return data["public"]
    raise FetchError(f"Unknown descriptor kind: {descriptor.kind}")


def _run_git(args: list[str], *, cwd: pathlib.Path | None = None) -> None:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        details = "\n".join(part for part in [stderr, stdout] if part)
        raise FetchError(f"git {' '.join(args)} failed:\n{details}")


def clone_url_for(descriptor: SourceDescriptor, token: str | None) -> str:
    """Build the HTTPS clone URL, injecting the App token for private repos only."""
    if descriptor.kind == "github_repo":
        if token:
            return (
                f"https://x-access-token:{token}@github.com/"
                f"{descriptor.owner}/{descriptor.name}.git"
            )
        return f"https://github.com/{descriptor.owner}/{descriptor.name}.git"
    if descriptor.kind == "gist":
        # Gists do not need authentication; even secret gists are clonable with the URL.
        return f"https://gist.github.com/{descriptor.owner}/{descriptor.name}.git"
    raise FetchError(f"Unknown descriptor kind: {descriptor.kind}")


def resolve_ref(
    descriptor: SourceDescriptor, clone_url: str
) -> str:
    """Resolve a descriptor to a concrete 40-char SHA.

    For commit-SHA refs, passes them through unchanged after format-checking.
    For branch/tag refs, uses `git ls-remote`.
    For refs that are `None`, uses HEAD.
    """
    ref = descriptor.ref
    if ref is not None and SHA_RE.fullmatch(ref):
        return ref
    lookup_ref = ref or "HEAD"
    result = subprocess.run(
        ["git", "ls-remote", clone_url, lookup_ref],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        raise FetchError(
            f"git ls-remote {clone_url} {lookup_ref} failed:\n{stderr}"
        )
    output = (result.stdout or "").strip()
    if not output:
        raise FetchError(
            f"Ref {lookup_ref!r} not found in {descriptor.owner}/{descriptor.name}."
        )
    first_line = output.splitlines()[0]
    sha, _, _ = first_line.partition("\t")
    sha = sha.strip()
    if not SHA_RE.fullmatch(sha):
        raise FetchError(
            f"git ls-remote returned unexpected SHA {sha!r} for {lookup_ref}."
        )
    return sha


def clone_at_sha(
    clone_url: str, sha: str, destination: pathlib.Path
) -> None:
    """Clone a specific commit into `destination` using the fetch-by-sha pattern.

    Avoids shallow-clone-plus-checkout which fails when the target commit is
    not reachable from the default branch in a shallow fetch.
    """
    destination.mkdir(parents=True, exist_ok=True)
    _run_git(["init", "--quiet"], cwd=destination)
    _run_git(["remote", "add", "origin", clone_url], cwd=destination)
    _run_git(["fetch", "--depth=1", "origin", sha], cwd=destination)
    _run_git(["checkout", "--quiet", "FETCH_HEAD"], cwd=destination)


def guard_no_path_escape(root: pathlib.Path) -> None:
    """Reject if any file inside `root` resolves outside `root`."""
    resolved_root = root.resolve()
    for path in root.rglob("*"):
        try:
            resolved = path.resolve(strict=False)
        except OSError as exc:
            raise FetchError(f"Failed to resolve {path}: {exc}") from exc
        try:
            resolved.relative_to(resolved_root)
        except ValueError as exc:
            raise FetchError(
                f"Path escape detected: {path} resolves to {resolved}, "
                f"outside {resolved_root}."
            ) from exc


def tar_source(source_dir: pathlib.Path, tar_path: pathlib.Path) -> None:
    tar_path.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(tar_path, "w:gz") as tf:
        tf.add(source_dir, arcname=source_dir.name)


def submission_repo_identifier(descriptor: SourceDescriptor) -> str:
    if descriptor.kind == "github_repo":
        return f"{descriptor.owner}/{descriptor.name}"
    if descriptor.kind == "gist":
        return f"{descriptor.owner}/{descriptor.name}"
    raise FetchError(f"Unknown descriptor kind: {descriptor.kind}")


def fetch_submission(
    *,
    event_payload: dict,
    output_dir: pathlib.Path,
    app_token: str | None,
    skip_clone: bool = False,
) -> dict:
    issue = event_payload.get("issue")
    if not isinstance(issue, dict):
        raise FetchError("Event payload is missing the `issue` object.")
    body = issue.get("body")
    if not isinstance(body, str) or not body.strip():
        raise FetchError("Issue body is empty.")
    issue_number = issue.get("number")
    if not isinstance(issue_number, int):
        raise FetchError("Event payload is missing `issue.number`.")
    user = issue.get("user")
    if not isinstance(user, dict):
        raise FetchError("Event payload is missing `issue.user`.")
    submitted_by = user.get("login")
    if not isinstance(submitted_by, str) or not submitted_by:
        raise FetchError("Event payload is missing `issue.user.login`.")

    fields = parse_issue_body(body)
    descriptor = parse_source_url(fields["source_url"])
    clone_url = clone_url_for(descriptor, app_token)
    sha = resolve_ref(descriptor, clone_url)

    submission_public = resolve_repo_visibility(descriptor, app_token)
    if descriptor.kind == "gist" and not submission_public:
        raise FetchError(
            "Secret (unlisted) gists are rejected in v1. "
            "Make your gist public, or host your proof in a public or "
            "App-accessible private GitHub repository."
        )

    source_dir = output_dir / "source"
    if not skip_clone:
        clone_at_sha(clone_url, sha, source_dir)
        guard_no_path_escape(source_dir)
        tar_source(source_dir, output_dir / "source.tar.gz")

    metadata = {
        "source_url": fields["source_url"],
        "submission_repo": submission_repo_identifier(descriptor),
        "submission_ref": sha,
        "submission_public": submission_public,
        "model": fields["model"],
        "submitted_by": submitted_by,
        "issue_number": issue_number,
    }
    metadata_path = output_dir / "metadata.json"
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return metadata


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--event-path",
        type=pathlib.Path,
        default=None,
        help="Path to the GitHub issue event payload JSON. "
        "Defaults to $GITHUB_EVENT_PATH.",
    )
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        required=True,
        help="Directory to write source.tar.gz and metadata.json.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Skip the clone; only parse the URL and emit metadata.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    try:
        args = _parse_args(argv)
        event_path = args.event_path or pathlib.Path(
            os.environ.get("GITHUB_EVENT_PATH", "")
        )
        if not event_path or not event_path.is_file():
            raise FetchError(
                "No event payload path provided. Set $GITHUB_EVENT_PATH or pass --event-path."
            )
        event_payload = json.loads(event_path.read_text(encoding="utf-8"))
        app_token = os.environ.get("APP_INSTALLATION_TOKEN") or None
        metadata = fetch_submission(
            event_payload=event_payload,
            output_dir=args.output_dir,
            app_token=app_token,
            skip_clone=args.dry_run,
        )
    except FetchError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(json.dumps(metadata, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
