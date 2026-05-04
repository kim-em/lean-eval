# Security model: lean-eval

This document explains why we believe the lean-eval submission pipeline
is resistant to adversarial submissions, what assumptions it depends on,
and where a future red-teamer should look first.

It is not a debugging log. The CI-postmortem narrative that previously
lived in `LANDRUN.md` is preserved in git history and replaced here by a
focused security write-up.

## 1. Threat model

The attacker controls:

- One submission they file as a GitHub issue: a public/private GitHub
  repo (or public gist) containing `Submission.lean` and any number of
  files under `Submission/**/*.lean`. Nothing else from the submission
  source is consumed.
- The freeform `model` and `production_description` fields in the issue
  body.

The attacker does not control:

- Whether the `submission` label gets applied — that requires triage
  permission on `leanprover/lean-eval`.
- `Challenge.lean`, `Solution.lean`, `lakefile.toml`, `lean-toolchain`,
  `config.json`, `WorkspaceTest.lean` in the generated workspace.
  These are taken from a pristine `generated/<id>/` checkout each run.
- Any pinned upstream commit (landrun, lean4export, comparator,
  GitHub Actions). See [Trusted dependencies and pin
  policy](#5-trusted-dependencies-and-pin-policy) for the assumption
  this places on each upstream.

The goal we resist: **a submitter receiving credit on the leaderboard
for a theorem they have not actually proved.**

## 2. Architecture: Challenge / Submission / Solution

Every benchmark problem ships as a self-contained Lake project in
[generated/<id>/](generated/two_plus_two/) with a fixed three-file shape:

- **Challenge.lean** is the trusted theorem statement, body `sorry`. The
  benchmark author writes this and reviewers approve it. It is what the
  problem ASKS.
- **Submission.lean** is the only file the solver edits. It must define
  a theorem of the same signature inside `namespace Submission`. This
  is what the solver provides as their PROOF.
- **Solution.lean** is a generated bridge: it has the same theorem
  signature as Challenge and provides `exact Submission.foo` (or, for
  multi-hole problems, the structured equivalent). It exists so that
  comparator can verify "Solution typechecks => Submission really
  proves Challenge."

[leanprover/comparator](https://github.com/leanprover/comparator) is the
verifier. Given a `config.json` listing `theorem_names`,
`definition_names`, and `permitted_axioms`, it:

1. Builds Challenge and Solution **separately** under a `landrun` Linux
   landlock sandbox, then runs `lean4export` on each (also sandboxed).
2. Walks the constant graph from each named theorem and requires that
   every transitively-used constant (other than def-hole targets, where
   only the type signature must match) is byte-identical between
   Challenge and Solution. See
   [comparator/Comparator/Compare.lean](../comparator/Comparator/Compare.lean).
3. Walks the same graph for axioms and requires every reachable axiom
   to be in the `permitted_axioms` allowlist. See
   [comparator/Comparator/Axioms.lean](../comparator/Comparator/Axioms.lean).
   Our allowlist is `{propext, Quot.sound, Classical.choice}`. Notably
   absent: `sorryAx` (so `sorry` is rejected) and `Lean.ofReduceBool`
   (so `native_decide` is rejected).
4. Replays the exported Solution environment into the in-process Lean
   kernel for a final type-check.

Because Solution's only proof step is `exact Submission.foo`, and
because Compare.lean rejects any drift in the constant graph from
Challenge's theorem statement, the only way for verification to succeed
is if `Submission.foo` is definitionally equal to a proof of Challenge's
exact theorem statement, using only the permitted axioms.

## 3. Where untrusted code runs, and what bounds it

User-submitted Lean is elaborated in exactly one place: comparator's
`safeLakeBuild Solution`, which runs `lake build Solution` (and
transitively `lake build Submission`) inside a landrun sandbox. Every
other step either does not elaborate Lean, or elaborates only trusted
code.

| Step | Process | Location | Elaborates Submission? |
|---|---|---|---|
| `actions/checkout` of lean-eval | trusted | runner | No |
| `rm -rf .git` | trusted | runner | No |
| `lake build comparator` (in `.ci/comparator/`) | trusted | runner | No |
| `lake build lean4export` (in `.ci/lean4export/`) | trusted | runner | No |
| Submission tarball extracted | inert data | runner | No |
| `evaluate_submission.py` overlay walk | trusted Python | runner | No |
| `_share_packages` symlink setup | trusted Python | runner | No |
| `_prime_workspace` runs `lake update` | parses TOML lakefile | runner | No |
| `_prime_workspace` runs `lake exe cache get` | downloads pre-built oleans | runner | No |
| `lake exe lean-eval run-eval` (host exe) | trusted Lean | runner | No |
| `lake test` builds `WorkspaceTest` | only `import Lean` | runner | No |
| `WorkspaceTest` spawns `lake env comparator config.json` | `lake env` is an env-shim | runner | No |
| `comparator` calls `lean --print-prefix` / `which git` | side-effect-free | runner | No |
| `comparator.safeLakeBuild Challenge` | trusted source, sandboxed | **inside landrun** | No |
| `comparator.safeExport challengeModule` | reads trusted olean | **inside landrun** | No |
| **`comparator.safeLakeBuild Solution`** | builds Solution -> imports Submission | **inside landrun** | **YES** |
| `comparator.safeExport solutionModule` | reads the just-built olean | **inside landrun** | No |
| `runKernel solution` | replays exported env in comparator process | runner | No |

Two boundary concerns to call out explicitly:

**Lake env doesn't elaborate.** [scripts/security_probes/lake_env_probe.py](scripts/security_probes/lake_env_probe.py)
verifies on every run of the test suite that `lake env -- <cmd>` (and
nested `lake env -- lake env -- <cmd>`) on a workspace whose
`Submission.lean` has top-level `initialize` and `#eval` markers does
NOT produce those markers in stdout. Confirmed on the pinned toolchain
(2026-05-04). If a future lake version starts evaluating project Lean
during `lake env`, this probe must be re-run before the toolchain
bump lands.

**`_prime_workspace` doesn't build user-controlled targets.** The
docstring at [scripts/evaluate_submission.py:288-322](scripts/evaluate_submission.py#L288-L322)
documents the rule and the regression history (commit `3474943`
violated it in 2026-04, reverted in #92 in 2026-05). `lake update` and
`lake exe cache get` are the only shell-outs allowed.

**Writable `.lake/`, and why the obvious tampering attack does not work.**
Comparator gives `safeLakeBuild` `--rwx <workspace>/.lake`, which is
necessary because lake writes its build outputs there. The natural
attack to consider is: a `Submission.lean` `initialize` block spawns a
detached `setsid` daemon that inherits landrun's filesystem rules,
survives the per-build landrun child's exit (children get reparented
to PID 1, not killed), and races to overwrite `Solution.olean` between
`safeLakeBuild Solution` returning and `safeExport solutionModule`
reading it — getting comparator to verify against an
attacker-controlled olean.

We ran [scripts/security_probes/artifact_tamper_probe.py](scripts/security_probes/artifact_tamper_probe.py)
on Linux (kernel 6.12 + landrun 5ed4a3db + comparator 71b52ec) on
2026-05-04 and the attack is **structurally impossible at the spawn
step**. Inside the sandbox, `IO.Process.spawn` succeeds only for the
`lean` binary; `sh`, `setsid`, `bash`, `cp`, `/bin/sh`, `/usr/bin/env`
all return exit 255 ("could not execute external process"). Comparator's
`safeLakeBuild` only `--rox`-whitelists `leanPrefix` and `gitLocation`;
landrun denies exec of anything else. The attacker has no way to
spawn a daemon, so there is nothing to race against `safeExport`.

This is a strong assumption to depend on. If a future comparator pin
broadens the executable allowlist (e.g. adds `sh`), or if a Lean
toolchain change allows the elaborator to spawn binaries by some other
path, this conclusion needs to be re-derived. Re-run the probe after
any landrun, comparator, or lean-toolchain pin bump.

## 4. Trust model for the comparator

We rely on the following claims about [leanprover/comparator](https://github.com/leanprover/comparator)
at the pinned commit:

1. The constant-graph walk in `compareAt` reaches every constant that
   the theorem's statement type or proof body transitively uses. If a
   constant is reachable, it must be byte-identical between Challenge
   and Solution unless it is listed in `definition_names` (which the
   benchmark author controls via the manifest).
2. The axiom walk in `checkAxioms` reaches every axiom transitively
   used by the theorem and definition targets, and rejects any axiom
   not in the configured allowlist.
3. `safeLakeBuild` and `safeExport` run inside landrun with the
   filesystem and environment policy described in
   `comparator/Main.lean`.
4. Lean kernel re-replay (`runKernel`) catches any malformed olean
   structure that lean4export accepts but the kernel rejects.

If any of those claims drifts in a future comparator commit, our
guarantees regress with it. The comparator pin (see Section 5) is the
mechanism that prevents silent drift; the bump procedure is the
mechanism that forces a re-audit.

## 5. Trusted dependencies and pin policy

Every external dependency of the submission pipeline is pinned to an
immutable commit SHA. Tags and branches are mutable; if `landrun@main`
or `actions/checkout@v4` is ever resolved at install time, the
upstream publisher controls our supply chain.

| Dependency | Repo | Pinned to | Purpose | Last bumped |
|---|---|---|---|---|
| landrun | zouuup/landrun | `5ed4a3db3a4ad930d577215c6b9abaa19df7f99f` | Linux landlock sandbox | 2026-05-04 |
| lean4export | leanprover/lean4export | `12581a6b680d8478175596338eb2d53383a323e3` | exports olean to text | 2026-05-04 |
| comparator | leanprover/comparator | `71b52ec29e06d4b7d882726553b1ceb99a2499e0` | the verifier | pre-2026-05 |
| `jlumbroso/free-disk-space` | (action) | `54081f138730dfa15788a46383842cd2f914a1be` | runner disk cleanup | 2026-05-04 |
| `actions/checkout` | (action) | `11bd71901bbe5b1630ceea73d27597364c9af683` | repo checkout | 2026-05-04 |
| `actions/setup-python` | (action) | `a26af69be951a213d495a4c3e4e4022e16d87065` | python setup | 2026-05-04 |
| `actions/setup-go` | (action) | `d35c59abb061a4a6fb18e82ac0862c26744d6ab5` | go setup | 2026-05-04 |
| `actions/upload-artifact` | (action) | `ea165f8d65b6e75b540449e92b4886f43607fa02` | artifact upload | 2026-05-04 |
| `actions/download-artifact` | (action) | `d3f86a106a0bac45b974a628896c90dbdf5c8093` | artifact download | 2026-05-04 |
| `actions/create-github-app-token` | (action) | `d72941d797fd3113feb6b93fd0dec494b13a2547` | App auth | 2026-05-04 |
| `leanprover/lean-action` | (action) | `38fbc41a8c28c4cbaec22d7f7de508ec2e7c0dd9` | Lean toolchain | 2026-05-04 |
| Go toolchain | (setup-go arg) | `1.24.0` | concrete version, not `stable` | 2026-05-04 |
| Python | (setup-python arg) | `3.11.10` | concrete patch version | 2026-05-04 |
| `permitted_axioms` (every workspace) | comparator config | `{propext, Quot.sound, Classical.choice}` | axioms allowed in proofs | unchanged |
| benchmark commit (leaderboard) | leanprover/lean-eval | `.benchmark-commit` in lean-eval-leaderboard | which lean-eval the live site reflects | per-bump |

Mutable selectors are forbidden anywhere in `.github/workflows/`. The
[`scripts/action_pin_audit.py`](scripts/action_pin_audit.py) script
walks every workflow and hard-fails on `uses: ...@main`,
`uses: ...@v<N>` (loose tag), `go-version: stable`, `python-version`
without a patch component, and `go install ...@<branch>`. It runs on
every CI build; an unpinned dependency cannot be merged.

### Bumping pinned dependencies

1. Find the new SHA. For tags: `git ls-remote <repo> refs/tags/<tag>`.
   For branch HEAD: `git ls-remote <repo> refs/heads/main`.
2. Update **every** site listed below in lockstep, and add a dated
   comment of the form `# <dep> pinned to <sha7> (<note> as of YYYY-MM-DD).`
   - `.github/workflows/ci.yml`
   - `.github/workflows/submission.yml`
   - `.github/workflows/regenerate-main.yml`
   - `scripts/check_comparator_installation.py` (`LANDRUN_INSTALL_TARGET`,
     for landrun only)
   - `lean-eval-leaderboard/.benchmark-commit` (for the lean-eval
     benchmark commit only)
3. Open a PR. CI runs `scripts/action_pin_audit.py`,
   `scripts/sandbox_engaged_probe.py`, and
   `scripts/security_probes/env_dump_probe.py`. All three must pass.
4. Re-run the one-shot probes locally on Linux:
   - [scripts/security_probes/lake_env_probe.py](scripts/security_probes/lake_env_probe.py)
   - [scripts/security_probes/artifact_tamper_probe.py](scripts/security_probes/artifact_tamper_probe.py)
   Update Sections 3 and 6 of this doc if either changes verdict.
5. Merge.

## 6. Validations done at submission time

- **Action pin audit.** [scripts/action_pin_audit.py](scripts/action_pin_audit.py)
  runs in CI; mutable workflow refs are blocked from merging.
- **Sandbox-engaged probe.** [scripts/sandbox_engaged_probe.py](scripts/sandbox_engaged_probe.py)
  runs in `ci.yml` and on every `submission` workflow run. It builds a
  synthetic comparator workspace whose `Submission.lean` attempts five
  writes — `/tmp/...`, `$HOME/...`, `../outside`, through a `.lake/`
  symlink to outside, and `.lake/probe/inside-ok` — and asserts only
  the inside-ok write succeeds. Catches landrun fail-open, kernel
  landlock regressions, and policy drift in comparator's flag set.
- **Env-allowlist probe.** [scripts/security_probes/env_dump_probe.py](scripts/security_probes/env_dump_probe.py)
  runs in `ci.yml` and on every `submission` workflow run. The probe
  salts the parent env with decoy secrets (`GH_TOKEN`,
  `LD_PRELOAD`, `AWS_ACCESS_KEY_ID`, `LEAN_EVAL_BOT_PRIVATE_KEY`,
  etc.) and asserts that `Submission`'s elaboration sees a subset
  of `{PATH, HOME, LEAN_ABORT_ON_PANIC, LEAN_PATH, LD_LIBRARY_PATH}`
  containing the required `{PATH, HOME, LEAN_ABORT_ON_PANIC}`.
  Allowlist-based, not spot-check, so the next unknown token class
  can't slip through. The required three are forwarded by comparator's
  `envPass`; `LEAN_PATH` and `LD_LIBRARY_PATH` are added by `lake`
  itself when it spawns `lean` and may or may not be present
  depending on the OS (NixOS sets both, Ubuntu typically only sets
  LEAN_PATH). They point at the workspace's `.lake/build/lib` and the
  toolchain's shared libs and contain no secrets. Confirmed
  empirically on Linux/NixOS on 2026-05-04 (runs both vars) and on
  Ubuntu GHA runners 2026-05-04 (runs only LEAN_PATH).
- **Overlay restriction.** `evaluate_submission.py:overlay_match` only
  copies `Submission.lean` and files matching `*.lean` under
  `Submission/`. Symlinks are rejected at submission walk and at
  overlay time; all paths are normalized and checked for traversal.
- **`_prime_workspace` invariant.** Only `lake update` + `lake exe
  cache get` are allowed before comparator runs. The docstring
  carries the rule and the regression history.
- **Permitted axioms.** Every generated `config.json` has
  `permitted_axioms = {propext, Quot.sound, Classical.choice}`. No
  `sorryAx`, no `Lean.ofReduceBool`.
- **Schema validation.** `update_leaderboard.py` validates
  `submission-ref` and `benchmark-commit` as 40-char hex SHAs,
  `submission-repo` as `owner/name`, `submission-kind` as `github_repo`
  or `gist`, and `--user` as a GitHub login regex.
- **Benchmark-commit pin.** The leaderboard's
  `scripts/generate_site_data.py` reads `.benchmark-commit` and aborts
  if the consumed `../lean-eval` checkout's HEAD does not match. The
  intended bumper of the live site is the leaderboard repo's
  `bump-benchmark-snapshot.yml` (not yet implemented; see Section 7).

## 7. Soft spots — where to look first

Each item is something we believe is OK today but where the assumption
is fragile or hard to audit.

1. **landrun `--best-effort` semantics on novel kernels.** landrun
   silently runs without sandbox if the kernel lacks landlock support.
   Today's `ubuntu-latest` runners are fine. The sandbox-engaged probe
   catches this in CI on every run, but the probe only exercises the
   policy comparator uses — if comparator's policy ever diverges from
   the probe's mock workspace shape, a real false negative is possible.
   Re-run the probe by hand on a clean Linux box after any landrun
   bump.
2. **Writable-`.lake` self-tampering** (Section 3). Currently neutralised
   by landrun's exec restriction (only `lean` can be exec'd from inside
   the sandbox; `sh`/`setsid`/etc. are denied), so the attacker cannot
   spawn the daemon the attack requires. This depends on comparator's
   `executablePaths` staying narrow. If a future comparator pin adds
   `sh` (or similar) to `executablePaths`, re-run `artifact_tamper_probe`
   and assume the attack is back in play until proven otherwise.
3. **`lake env` behaviour across lake versions.** The `lake_env_probe`
   confirms current behaviour. Lake version bumps must re-run it.
4. **`definition_names` author trap.** Comparator only requires that
   def/instance holes match Challenge in TYPE, not body. If the
   benchmark author writes a theorem whose statement does not pin the
   def's value, a submitter can satisfy the manifest with a trivial
   def. There is no automated guard against this — comparator
   structurally cannot verify that an author's spec theorems
   sufficiently constrain a def — and adding one would be at most a
   heuristic. The real guard is PR review of any problem that uses
   def/instance holes.
5. **HTML escaping of freeform fields on the leaderboard.** The
   `model` and `production_description` fields are unbounded freeform
   text from the issue body, propagated into `leaderboard.json` and
   rendered by Verso. Verso/markdown should escape but this has not
   been explicitly probed.
6. **Leaderboard deploy doesn't yet enforce `.benchmark-commit`.**
   `lean-eval-leaderboard/.github/workflows/deploy.yml` currently
   builds from frozen `site-data/`; `generate_site_data.py` is invoked
   out-of-band. The pin guard added in this work fires only when the
   script runs. The intended `bump-benchmark-snapshot.yml` workflow
   that would close this gap does not yet exist; tracked as follow-up.
7. **Single-kernel defence.** `enable_nanoda: false` in every
   generated config means the alternate kernel is not run. A Lean
   kernel soundness bug becomes a false-credit vector. Defence in
   depth would be `enable_nanoda: true` once nanoda's string
   handling is upstream-fixed.
8. **Freeform `model` length.** `update_leaderboard.py` validates
   `production_description` length but not `model`. A pathological
   `model` value cannot grant credit, but can pollute the
   leaderboard JSON.
9. **The `submission` label is a triage gate.** Anyone with triage
   access on `leanprover/lean-eval` can trigger the workflow against
   any submission URL. Repository admin hygiene matters.

## References

- [comparator/Main.lean](../comparator/Main.lean), [comparator/Comparator/Compare.lean](../comparator/Comparator/Compare.lean), [comparator/Comparator/Axioms.lean](../comparator/Comparator/Axioms.lean) — verifier internals.
- [leanprover/comparator README](https://github.com/leanprover/comparator) — upstream trust model.
- [scripts/security_probes/](scripts/security_probes/) — the four security probes cited above.
- [scripts/action_pin_audit.py](scripts/action_pin_audit.py),
  [scripts/sandbox_engaged_probe.py](scripts/sandbox_engaged_probe.py),
  [scripts/check_comparator_installation.py](scripts/check_comparator_installation.py),
  [scripts/evaluate_submission.py](scripts/evaluate_submission.py),
  [scripts/update_leaderboard.py](scripts/update_leaderboard.py),
  [scripts/validate_manifest.py](scripts/validate_manifest.py) — the pipeline scripts referenced from this document.
- Workflow files: [.github/workflows/submission.yml](.github/workflows/submission.yml), [.github/workflows/ci.yml](.github/workflows/ci.yml), [.github/workflows/regenerate-main.yml](.github/workflows/regenerate-main.yml), [.github/workflows/notify-leaderboard.yml](.github/workflows/notify-leaderboard.yml).
