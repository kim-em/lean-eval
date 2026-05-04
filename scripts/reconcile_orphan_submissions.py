#!/usr/bin/env python3
"""Close `submission`-labeled issues that the Submission workflow never
responded to. See .github/workflows/submission-reconciler.yml."""
from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys

ORPHAN_THRESHOLD = dt.timedelta(hours=2)
BOT_AUTHORS = {"github-actions[bot]", "lean-eval-bot[bot]"}
SUBMISSION_WORKFLOW = "submission.yml"


def gh(args: list[str]) -> str:
    return subprocess.run(
        ["gh", *args], check=True, capture_output=True, text=True
    ).stdout


def gh_json(args: list[str]):
    return json.loads(gh(args))


def parse_iso(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def find_run_for_issue(repo: str, issue_title: str) -> str | None:
    """Best-effort fuzzy match: latest submission-workflow run on `issues`
    event whose display_title equals the issue title."""
    runs = gh_json(
        [
            "api",
            f"repos/{repo}/actions/workflows/{SUBMISSION_WORKFLOW}/runs",
            "--jq",
            "[.workflow_runs[] | select(.event == \"issues\") "
            "| {id, display_title, html_url}]",
            "-X",
            "GET",
            "-F",
            "per_page=50",
        ]
    )
    for run in runs:
        if run["display_title"] == issue_title:
            return run["html_url"]
    return None


def main() -> int:
    repo = os.environ["REPO"]
    server_url = os.environ["SERVER_URL"]
    now = dt.datetime.now(dt.timezone.utc)

    issues = gh_json(
        [
            "issue",
            "list",
            "--repo",
            repo,
            "--state",
            "open",
            "--label",
            "submission",
            "--limit",
            "200",
            "--json",
            "number,title,createdAt,comments",
        ]
    )

    for issue in issues:
        number = issue["number"]
        created = parse_iso(issue["createdAt"])
        if now - created < ORPHAN_THRESHOLD:
            continue
        has_bot_comment = any(
            c["author"]["login"] in BOT_AUTHORS for c in issue["comments"]
        )
        if has_bot_comment:
            continue

        run_url = find_run_for_issue(repo, issue["title"])
        if run_url:
            run_line = f"Most recent workflow run: {run_url}."
        else:
            run_line = (
                f"No matching workflow run was found in the recent history "
                f"({server_url}/{repo}/actions/workflows/{SUBMISSION_WORKFLOW})."
            )

        body = (
            "⚠️ The submission pipeline did not post a result for this "
            f"issue within {int(ORPHAN_THRESHOLD.total_seconds() // 3600)}h. "
            f"{run_line} Closing as orphaned — please re-submit if you'd "
            "like to try again."
        )
        print(f"reconciling #{number}: {issue['title']!r}", file=sys.stderr)
        gh(["issue", "comment", str(number), "--repo", repo, "--body", body])
        gh(
            [
                "issue",
                "close",
                str(number),
                "--repo",
                repo,
                "--reason",
                "not planned",
            ]
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
