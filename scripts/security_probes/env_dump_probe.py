#!/usr/bin/env python3
"""
Assert that comparator's landrun sandbox exposes EXACTLY the env-var
allowlist we expect to user-controlled Submission elaboration — no more,
no less.

Codex correctly pushed back on a spot-check probe ("does GH_TOKEN leak?
does ANTHROPIC_API_KEY leak?") because spot checks miss the next
unknown token class. This probe is allowlist-based: the parent shell
sets a battery of decoy-secret env vars, the Submission's initialize
block dumps every env var visible to it, and the probe asserts the
visible set is exactly:

    {PATH, HOME, LEAN_ABORT_ON_PANIC}

Anything else, named or unnamed, is a hard failure.

Cross-reference: comparator/Main.lean's `safeLakeBuild` whitelists
exactly those three via `envPass` (see the pinned comparator at SHA
71b52ec... lines 76-85 in Main.lean). If that allowlist ever drifts —
e.g. a future comparator pin adds GIT_AUTHOR_NAME, or our env
override gets bypassed — this probe must catch it.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
TOOLCHAIN = (REPO_ROOT / "lean-toolchain").read_text(encoding="utf-8").strip()


# Vars we EXPECT Submission's elaboration to see. The set has two
# sources, both of which need updating in lockstep with this constant:
#   1. Comparator's `envPass` whitelists which parent env vars landrun
#      forwards: PATH, HOME, LEAN_ABORT_ON_PANIC. Sensitive secrets
#      (GH_TOKEN, AWS_*, LD_PRELOAD, etc.) are stripped here.
#   2. Lake itself injects LEAN_PATH and LD_LIBRARY_PATH when invoking
#      `lean` to build a module — these point at the workspace's
#      .lake/build/lib and the toolchain's shared libs respectively.
#      They are NOT secrets and are expected; they are required for
#      lean to find its imports.
# If this set ever changes intentionally, update SECURITY.md >
# "Validations done at submission time" > env allowlist accordingly.
EXPECTED_VISIBLE = {
    "PATH", "HOME", "LEAN_ABORT_ON_PANIC",
    "LEAN_PATH", "LD_LIBRARY_PATH",
}

# A representative sample of decoy secrets we shove into the parent env
# before invoking comparator. These are NOT the only vars we care about —
# the test is allowlist-based, so any leak is detected — but salting the
# parent env with realistic-looking secrets makes a leak observable in
# the failure message.
DECOY_SECRETS = {
    "GH_TOKEN":                   "ghs_PROBE-decoy-do-not-trust",
    "GITHUB_TOKEN":               "ghs_PROBE-decoy-do-not-trust",
    "LEADERBOARD_WRITE_TOKEN":    "ghp_PROBE-decoy-do-not-trust",
    "ANTHROPIC_API_KEY":          "sk-ant-PROBE-decoy",
    "OPENAI_API_KEY":             "sk-PROBE-decoy",
    "AWS_ACCESS_KEY_ID":          "AKIAPROBEDECOY0000",
    "AWS_SECRET_ACCESS_KEY":      "PROBE/decoy/secret/key/value/000",
    "ACTIONS_RUNTIME_TOKEN":      "PROBE-decoy-actions-runtime",
    "ACTIONS_ID_TOKEN_REQUEST_URL": "https://example.invalid/probe",
    "RUNNER_TOKEN":               "PROBE-decoy-runner",
    "CI":                         "true",
    "GITHUB_ACTIONS":             "true",
    "SSH_AUTH_SOCK":              "/tmp/probe-ssh-auth-sock-decoy",
    "LD_PRELOAD":                 "/tmp/probe-ldpreload-decoy.so",
    "LEAN_EVAL_BOT_PRIVATE_KEY":  "-----BEGIN PRIVATE KEY-----\nPROBEDECOY\n-----END PRIVATE KEY-----",
}


SUBMISSION_LEAN = r"""
import Lean

initialize do
  -- Comparator's landrun policy denies exec of `sh`/`printenv`/etc.
  -- (only `lean` itself can be exec'd from inside the sandbox; see
  -- artifact_tamper_probe Phase A). So we read /proc/self/environ
  -- directly. /proc is readable under landrun's `--ro /` rule.
  -- We dump the raw NUL-separated bytes; Python on the harness side
  -- splits and extracts key names. Avoids any String/UTF8 fragility
  -- inside Lean.
  let cwd ← IO.currentDir
  let outDir : System.FilePath := cwd / ".lake" / "probe"
  IO.FS.createDirAll outDir
  let bytes ← IO.FS.readBinFile "/proc/self/environ"
  IO.FS.writeBinFile (outDir / "environ.raw") bytes
"""

CHALLENGE_LEAN = """\
theorem env_dump_probe_thm : True := True.intro
"""

SUBMISSION_THM_LEAN = """\
namespace Submission
theorem env_dump_probe_thm : True := True.intro
end Submission
"""

SOLUTION_LEAN = """\
import Submission
import Submission.Thm

theorem env_dump_probe_thm : True := Submission.env_dump_probe_thm
"""

LAKEFILE_TOML = """\
name = "env_dump_probe"
defaultTargets = ["Challenge", "Solution", "Submission"]

[[lean_lib]]
name = "Challenge"

[[lean_lib]]
name = "Solution"

[[lean_lib]]
name = "Submission"
"""

CONFIG_JSON = {
    "challenge_module": "Challenge",
    "solution_module": "Solution",
    "theorem_names": ["env_dump_probe_thm"],
    "permitted_axioms": ["propext", "Quot.sound", "Classical.choice"],
    "enable_nanoda": False,
}


class ProbeError(Exception):
    pass


def _check_tools(require: bool) -> list[str]:
    missing = [t for t in ("lake", "lean", "landrun", "comparator") if shutil.which(t) is None]
    if missing and require:
        raise ProbeError(f"Required tools not on PATH: {', '.join(missing)}.")
    return missing


def _write_workspace(workspace: pathlib.Path) -> None:
    (workspace / "lakefile.toml").write_text(LAKEFILE_TOML, encoding="utf-8")
    (workspace / "lean-toolchain").write_text(TOOLCHAIN + "\n", encoding="utf-8")
    (workspace / "Challenge.lean").write_text(CHALLENGE_LEAN, encoding="utf-8")
    (workspace / "Solution.lean").write_text(SOLUTION_LEAN, encoding="utf-8")
    (workspace / "Submission.lean").write_text(SUBMISSION_LEAN, encoding="utf-8")
    sub = workspace / "Submission"
    sub.mkdir(parents=True, exist_ok=True)
    (sub / "Thm.lean").write_text(SUBMISSION_THM_LEAN, encoding="utf-8")
    (workspace / "config.json").write_text(
        json.dumps(CONFIG_JSON, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def _run_comparator(workspace: pathlib.Path, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    subprocess.run(["lake", "update"], cwd=workspace, capture_output=True, text=True, check=False)
    return subprocess.run(
        ["lake", "env", "comparator", "config.json"],
        cwd=workspace,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def _read_visible(workspace: pathlib.Path) -> set[str]:
    out = workspace / ".lake" / "probe" / "environ.raw"
    if not out.is_file():
        raise ProbeError(
            f"Submission's env dump did not appear at {out}; the initialize "
            "block may not have run, or the writable-path rule was dropped."
        )
    raw = out.read_bytes()
    names: set[str] = set()
    for entry in raw.split(b"\x00"):
        if not entry:
            continue
        key, _, _ = entry.partition(b"=")
        try:
            names.add(key.decode("utf-8"))
        except UnicodeDecodeError:
            names.add(key.decode("latin-1"))
    return names


def run_probe(*, require_tools: bool = False) -> int:
    missing = _check_tools(require=require_tools)
    if missing and not require_tools:
        print(
            f"env_dump_probe: skipped (missing tools: {', '.join(missing)}). "
            "Re-run with --require-tools (or in CI) to make this an error.",
            file=sys.stderr,
        )
        return 0
    parent_env = os.environ.copy()
    # Salt the parent env with realistic-looking secrets so a leak would
    # be both detectable AND visible in the failure message. The decoy
    # values are obvious garbage; nothing real is exposed.
    parent_env.update(DECOY_SECRETS)
    with tempfile.TemporaryDirectory(prefix="env_dump_probe_") as tmp:
        workspace = pathlib.Path(tmp) / "ws"
        workspace.mkdir(parents=True)
        _write_workspace(workspace)
        result = _run_comparator(workspace, parent_env)
        if result.returncode != 0:
            sys.stderr.write(
                f"env_dump_probe: comparator exited {result.returncode}. Output:\n"
            )
            if result.stdout:
                sys.stderr.write(result.stdout)
            if result.stderr:
                sys.stderr.write(result.stderr)
        try:
            visible = _read_visible(workspace)
        except ProbeError as exc:
            print(f"env_dump_probe: FAIL\n  {exc}", file=sys.stderr)
            return 1
        unexpected = visible - EXPECTED_VISIBLE
        missing_expected = EXPECTED_VISIBLE - visible
        if unexpected or missing_expected:
            print("env_dump_probe: FAIL — env allowlist drifted.", file=sys.stderr)
            if unexpected:
                # Sort and limit length so a 100-var leak is still legible.
                sample = sorted(unexpected)
                shown = ", ".join(sample[:25])
                more = f" (+{len(sample)-25} more)" if len(sample) > 25 else ""
                print(f"  - LEAKED to Submission: {shown}{more}", file=sys.stderr)
                # Highlight any decoys that leaked, since those carry the
                # known-secret signal.
                leaked_decoys = sorted(unexpected & set(DECOY_SECRETS.keys()))
                if leaked_decoys:
                    print(
                        f"  - of which decoys (means real secrets would also leak): {', '.join(leaked_decoys)}",
                        file=sys.stderr,
                    )
            if missing_expected:
                print(
                    f"  - missing expected: {', '.join(sorted(missing_expected))}. "
                    "If a needed var is missing, comparator's safeLakeBuild "
                    "may have stopped passing it.",
                    file=sys.stderr,
                )
            return 1
    print("env_dump_probe: PASS — Submission sees exactly", sorted(EXPECTED_VISIBLE))
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--require-tools",
        action="store_true",
        help="Treat missing tools as error (CI must pass this).",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        return run_probe(require_tools=args.require_tools)
    except ProbeError as exc:
        print(f"env_dump_probe: error\n  {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
