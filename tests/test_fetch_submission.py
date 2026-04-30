from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import fetch_submission as fs  # noqa: E402


SAMPLE_BODY = """### Submission URL

https://github.com/alice/my-proofs/commit/8e1b9cf5e1d3c2b1a0f9e8d7c6b5a4938271605f

### Model

Claude Opus 4.6

### Acknowledgements

- [X] I understand that the lean-eval CI will clone my submission repo at the given SHA and run comparator on it.
- [X] I understand that only the set of solved problem IDs, along with the metadata I entered above, will be published to the public leaderboard results store.
"""


class ParseIssueBodyTests(unittest.TestCase):
    def test_extracts_url_and_model(self) -> None:
        fields = fs.parse_issue_body(SAMPLE_BODY)
        self.assertEqual(
            fields["source_url"],
            "https://github.com/alice/my-proofs/commit/8e1b9cf5e1d3c2b1a0f9e8d7c6b5a4938271605f",
        )
        self.assertEqual(fields["model"], "Claude Opus 4.6")
        self.assertIsNone(fields["production_description"])

    def test_missing_url_section_is_fatal(self) -> None:
        body = "### Model\n\nClaude\n"
        with self.assertRaisesRegex(fs.FetchError, "Submission URL"):
            fs.parse_issue_body(body)

    def test_missing_model_section_is_fatal(self) -> None:
        body = "### Submission URL\n\nhttps://github.com/a/b\n"
        with self.assertRaisesRegex(fs.FetchError, "Model"):
            fs.parse_issue_body(body)

    def test_empty_field_is_fatal(self) -> None:
        body = "### Submission URL\n\n_No response_\n\n### Model\n\nFoo\n"
        with self.assertRaisesRegex(fs.FetchError, "empty"):
            fs.parse_issue_body(body)

    def test_production_description_extracted(self) -> None:
        body = (
            "### Submission URL\n\nhttps://github.com/alice/my-proofs\n\n"
            "### Model\n\nClaude Opus 4.6\n\n"
            "### How this solution was produced (optional)\n\n"
            "Driven by a custom orchestrator. ~30 min of human review.\n"
        )
        fields = fs.parse_issue_body(body)
        self.assertEqual(
            fields["production_description"],
            "Driven by a custom orchestrator. ~30 min of human review.",
        )

    def test_production_description_no_response_treated_as_absent(self) -> None:
        body = (
            "### Submission URL\n\nhttps://github.com/alice/my-proofs\n\n"
            "### Model\n\nClaude Opus 4.6\n\n"
            "### How this solution was produced (optional)\n\n_No response_\n"
        )
        fields = fs.parse_issue_body(body)
        self.assertIsNone(fields["production_description"])

    def test_production_description_oversize_is_fatal(self) -> None:
        oversize = "x" * (fs.PRODUCTION_DESCRIPTION_MAX_LEN + 1)
        body = (
            "### Submission URL\n\nhttps://github.com/alice/my-proofs\n\n"
            "### Model\n\nClaude Opus 4.6\n\n"
            f"### How this solution was produced (optional)\n\n{oversize}\n"
        )
        with self.assertRaisesRegex(fs.FetchError, "longer than"):
            fs.parse_issue_body(body)


class ParseSourceUrlTests(unittest.TestCase):
    def test_github_repo_root(self) -> None:
        d = fs.parse_source_url("https://github.com/alice/my-proofs")
        self.assertEqual(d.kind, "github_repo")
        self.assertEqual(d.owner, "alice")
        self.assertEqual(d.name, "my-proofs")
        self.assertIsNone(d.ref)

    def test_github_repo_root_dot_git_suffix(self) -> None:
        d = fs.parse_source_url("https://github.com/alice/my-proofs.git")
        self.assertEqual(d.kind, "github_repo")
        self.assertEqual(d.name, "my-proofs")
        self.assertIsNone(d.ref)

    def test_github_tree_with_branch(self) -> None:
        d = fs.parse_source_url("https://github.com/alice/my-proofs/tree/main")
        self.assertEqual(d.kind, "github_repo")
        self.assertEqual(d.ref, "main")

    def test_github_tree_with_sha(self) -> None:
        sha = "8e1b9cf5e1d3c2b1a0f9e8d7c6b5a4938271605f"
        d = fs.parse_source_url(f"https://github.com/alice/my-proofs/tree/{sha}")
        self.assertEqual(d.ref, sha)

    def test_github_commit_url(self) -> None:
        sha = "deadbeefcafef00dbaadc0de1234567890abcdef"
        d = fs.parse_source_url(f"https://github.com/alice/my-proofs/commit/{sha}")
        self.assertEqual(d.ref, sha)

    def test_github_trailing_slash_allowed(self) -> None:
        d = fs.parse_source_url("https://github.com/alice/my-proofs/")
        self.assertEqual(d.owner, "alice")

    def test_gist_bare(self) -> None:
        d = fs.parse_source_url("https://gist.github.com/alice/abc123def456")
        self.assertEqual(d.kind, "gist")
        self.assertEqual(d.owner, "alice")
        self.assertEqual(d.name, "abc123def456")
        self.assertIsNone(d.ref)

    def test_gist_with_revision(self) -> None:
        d = fs.parse_source_url(
            "https://gist.github.com/alice/abc123def456/deadbeefcafe"
        )
        self.assertEqual(d.kind, "gist")
        self.assertEqual(d.ref, "deadbeefcafe")

    def test_reject_owner_repo_shorthand(self) -> None:
        with self.assertRaisesRegex(fs.FetchError, "https"):
            fs.parse_source_url("alice/my-proofs")

    def test_reject_query_string(self) -> None:
        with self.assertRaisesRegex(fs.FetchError, r"\?"):
            fs.parse_source_url("https://github.com/alice/my-proofs?tab=readme")

    def test_reject_fragment(self) -> None:
        with self.assertRaisesRegex(fs.FetchError, "#"):
            fs.parse_source_url("https://github.com/alice/my-proofs#readme")

    def test_reject_non_github_host(self) -> None:
        with self.assertRaisesRegex(fs.FetchError, "Unsupported host"):
            fs.parse_source_url("https://gitlab.com/alice/my-proofs")

    def test_reject_codeload(self) -> None:
        with self.assertRaisesRegex(fs.FetchError, "Unsupported host"):
            fs.parse_source_url("https://codeload.github.com/alice/my-proofs")

    def test_reject_http_scheme(self) -> None:
        with self.assertRaisesRegex(fs.FetchError, "https"):
            fs.parse_source_url("http://github.com/alice/my-proofs")

    def test_reject_github_pull_url(self) -> None:
        with self.assertRaisesRegex(fs.FetchError, "unsupported shape"):
            fs.parse_source_url("https://github.com/alice/my-proofs/pull/123")

    def test_reject_malformed_gist(self) -> None:
        with self.assertRaisesRegex(fs.FetchError, "unsupported shape"):
            fs.parse_source_url("https://gist.github.com/alice")


class ResolveRefTests(unittest.TestCase):
    def test_40_char_sha_passthrough(self) -> None:
        descriptor = fs.SourceDescriptor(
            kind="github_repo",
            owner="alice",
            name="my-proofs",
            ref="8e1b9cf5e1d3c2b1a0f9e8d7c6b5a4938271605f",
        )
        # Should not touch the network at all.
        sha = fs.resolve_ref(descriptor, "https://example.invalid/unused.git")
        self.assertEqual(sha, "8e1b9cf5e1d3c2b1a0f9e8d7c6b5a4938271605f")

    def test_uses_ls_remote_for_branch(self) -> None:
        descriptor = fs.SourceDescriptor(
            kind="github_repo",
            owner="alice",
            name="my-proofs",
            ref="main",
        )
        fake_output = "1234567890abcdef1234567890abcdef12345678\trefs/heads/main\n"
        with patch("fetch_submission.subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=["git"], returncode=0, stdout=fake_output, stderr=""
            )
            sha = fs.resolve_ref(descriptor, "https://example.invalid/x.git")
        self.assertEqual(sha, "1234567890abcdef1234567890abcdef12345678")

    def test_missing_ref_raises(self) -> None:
        descriptor = fs.SourceDescriptor(
            kind="github_repo",
            owner="alice",
            name="my-proofs",
            ref="nonexistent-branch",
        )
        with patch("fetch_submission.subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=["git"], returncode=0, stdout="", stderr=""
            )
            with self.assertRaisesRegex(fs.FetchError, "not found"):
                fs.resolve_ref(descriptor, "https://example.invalid/x.git")


class CloneUrlTests(unittest.TestCase):
    def test_public_github_repo_no_token(self) -> None:
        d = fs.SourceDescriptor(
            kind="github_repo", owner="alice", name="my-proofs", ref=None
        )
        self.assertEqual(
            fs.clone_url_for(d, None),
            "https://github.com/alice/my-proofs.git",
        )

    def test_private_github_repo_with_token_injects_basic_auth(self) -> None:
        d = fs.SourceDescriptor(
            kind="github_repo", owner="alice", name="secret", ref=None
        )
        self.assertEqual(
            fs.clone_url_for(d, "ghs_abc123"),
            "https://x-access-token:ghs_abc123@github.com/alice/secret.git",
        )

    def test_gist_never_injects_token(self) -> None:
        d = fs.SourceDescriptor(
            kind="gist", owner="alice", name="abc123", ref=None
        )
        self.assertEqual(
            fs.clone_url_for(d, "ghs_abc123"),
            "https://gist.github.com/alice/abc123.git",
        )


class CloneAtShaTests(unittest.TestCase):
    """Integration test against a local git fixture."""

    def _make_fixture_repo(self, tmp_path: pathlib.Path) -> tuple[pathlib.Path, str]:
        repo = tmp_path / "origin"
        repo.mkdir()
        subprocess.run(["git", "init", "--quiet"], cwd=repo, check=True)
        subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=repo, check=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=repo, check=True)
        (repo / "README.md").write_text("hello\n")
        subprocess.run(["git", "add", "README.md"], cwd=repo, check=True)
        subprocess.run(
            ["git", "commit", "-m", "init", "--no-gpg-sign"],
            cwd=repo,
            check=True,
        )
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=repo,
            check=True,
            capture_output=True,
            text=True,
        )
        return repo, result.stdout.strip()

    def test_clone_at_sha_against_local_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            origin, sha = self._make_fixture_repo(tmp_path)
            destination = tmp_path / "dest"
            fs.clone_at_sha(str(origin), sha, destination)
            self.assertTrue((destination / "README.md").is_file())
            self.assertEqual(
                (destination / "README.md").read_text(encoding="utf-8"),
                "hello\n",
            )


class GuardPathEscapeTests(unittest.TestCase):
    def test_clean_tree_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            (tmp_path / "a").mkdir()
            (tmp_path / "a" / "f.txt").write_text("x")
            fs.guard_no_path_escape(tmp_path)

    def test_symlink_escape_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            inside = tmp_path / "inside"
            outside = tmp_path / "outside"
            inside.mkdir()
            outside.mkdir()
            (outside / "secret.txt").write_text("nope")
            (inside / "link").symlink_to(outside / "secret.txt")
            with self.assertRaisesRegex(fs.FetchError, "Path escape"):
                fs.guard_no_path_escape(inside)


class FetchSubmissionEndToEndTests(unittest.TestCase):
    def test_dry_run_emits_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            event = {
                "issue": {
                    "number": 42,
                    "user": {"login": "alice"},
                    "body": SAMPLE_BODY,
                }
            }
            sha = "8e1b9cf5e1d3c2b1a0f9e8d7c6b5a4938271605f"
            with patch("fetch_submission.resolve_repo_visibility", return_value=True):
                metadata = fs.fetch_submission(
                    event_payload=event,
                    output_dir=tmp_path / "out",
                    app_token=None,
                    skip_clone=True,
                )
            self.assertEqual(metadata["submission_repo"], "alice/my-proofs")
            self.assertEqual(metadata["submission_ref"], sha)
            self.assertTrue(metadata["submission_public"])
            self.assertEqual(metadata["model"], "Claude Opus 4.6")
            self.assertEqual(metadata["submitted_by"], "alice")
            self.assertEqual(metadata["issue_number"], 42)
            self.assertNotIn("production_description", metadata)
            disk_metadata = json.loads(
                (tmp_path / "out" / "metadata.json").read_text(encoding="utf-8")
            )
            self.assertEqual(disk_metadata, metadata)

    def test_dry_run_emits_production_description_when_present(self) -> None:
        body_with_description = (
            SAMPLE_BODY.rstrip()
            + "\n\n### How this solution was produced (optional)\n\n"
            "Custom orchestrator + Claude Opus 4.7; ~30 min human review.\n"
        )
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            event = {
                "issue": {
                    "number": 42,
                    "user": {"login": "alice"},
                    "body": body_with_description,
                }
            }
            with patch("fetch_submission.resolve_repo_visibility", return_value=True):
                metadata = fs.fetch_submission(
                    event_payload=event,
                    output_dir=tmp_path / "out",
                    app_token=None,
                    skip_clone=True,
                )
            self.assertEqual(
                metadata["production_description"],
                "Custom orchestrator + Claude Opus 4.7; ~30 min human review.",
            )

    def test_secret_gist_is_rejected(self) -> None:
        gist_body = SAMPLE_BODY.replace(
            "https://github.com/alice/my-proofs/commit/8e1b9cf5e1d3c2b1a0f9e8d7c6b5a4938271605f",
            "https://gist.github.com/alice/abc123def456",
        )
        event = {
            "issue": {
                "number": 42,
                "user": {"login": "alice"},
                "body": gist_body,
            }
        }
        with tempfile.TemporaryDirectory() as tmp:
            with patch("fetch_submission.resolve_repo_visibility", return_value=False):
                with patch(
                    "fetch_submission.resolve_ref",
                    return_value="a" * 40,
                ):
                    with self.assertRaisesRegex(fs.FetchError, "Secret"):
                        fs.fetch_submission(
                            event_payload=event,
                            output_dir=pathlib.Path(tmp),
                            app_token=None,
                            skip_clone=True,
                        )

    def test_missing_issue_body_is_fatal(self) -> None:
        event = {"issue": {"number": 1, "user": {"login": "alice"}, "body": ""}}
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(fs.FetchError, "body is empty"):
                fs.fetch_submission(
                    event_payload=event,
                    output_dir=pathlib.Path(tmp),
                    app_token=None,
                    skip_clone=True,
                )


if __name__ == "__main__":
    unittest.main()
