# LANDRUN.md — comparator/landrun denial in CI

A living dossier on a sandbox denial that blocked every CI attempt to run
comparator on this repository. This is now root-caused and has a repo-local
workaround.

## TL;DR

The original CI failure was:

```
Building Challenge
[landrun:error] 2026/04/11 15:12:50 permission denied
uncaught exception: Child exited with 1
```

Root cause on Linux turned out to be two comparator / landrun integration bugs:

1. `safeLakeBuild` invoked `cmd := "lake"`, which resolves to the static elan
   launcher (`~/.elan/bin/lake`) on typical setups. landrun's `-ldd` handling
   cannot derive useful runtime dependencies from that launcher, so the sandbox
   failed before it ever reached the real toolchain `lake`.
2. Even after switching to the real toolchain binary
   (`$(lean --print-prefix)/bin/lake`), landrun still omitted the ELF
   interpreter (for example `/lib/ld-linux-x86-64.so.2` on GitHub Actions or
   `/lib/ld-linux-aarch64.so.1` on ARM Ubuntu), so `execve` still failed with
   `EACCES`.

The repo-local workaround is `patches/comparator-landrun.patch`, applied in
both `.github/workflows/ci.yml` and `.github/workflows/submission.yml` before
building comparator. The patch:

- resolves `lake` to the real toolchain binary instead of the elan shim
- resolves `lean4export` and `nanoda_bin` to concrete paths as well
- runs `ldd` on each concrete binary and explicitly whitelists the dynamic
  loader path that landrun misses

The previous `HOME=.lake/home` workaround attempted in this repo was removed;
it was not the real issue and can break elan-based setups by moving the launcher
to a different home.

The denial happens on `ubuntu-latest` GitHub Actions runners, **regardless**
of:

- where the workspace lives on disk (`/tmp/...`, `<repo>/.submission-*`,
  `<repo>/generated/<id>/`)
- whether the workspace's packages have been primed via `lake update` +
  `lake exe cache get` outside the sandbox
- whether `Challenge`, `Solution`, and `Submission` have already been built
  outside the sandbox (so that comparator's sandboxed `lake build Challenge`
  should be a no-op)
- whether `.lake/packages` is a real directory or a symlink to a shared
  canonical location

Landrun prints `permission denied` without any path context, so we cannot
tell which syscall or which path tripped the denial. `check_comparator_installation.py`
(the minimal local reproducer that predates this work) hits the same denial
in CI, which suggests the problem is not in `scripts/evaluate_submission.py`
or in the submission workflow — **`ci.yml` on main has been failing on
every recent commit for this reason**, and nobody noticed because the CI
run was interpreted as green until this investigation started.

We need either

1. more visibility into what landrun is denying (verbose landrun logs,
   `auditd` on the runner, or `strace` of the sandboxed lake process), or
2. a reproduction on a local Linux box with the same kernel/landlock
   version as `ubuntu-latest`, where we can iterate quickly, or
3. a targeted patch to comparator's landrun config with extra writable or
   readable paths informed by (1) or (2).

The submission pipeline this LANDRUN.md blocks is otherwise mechanically
complete: fetch → evaluate → record all run green, the issue is commented
on and closed, and the leaderboard receives (an empty) update.

## The setup

### Relevant repositories

- `kim-em/lean-eval` — the benchmark. This repo.
- `kim-em/lean-eval-leaderboard` — the public results store. Write-only from CI.
- `kim-em/lean-eval-dogfood` — throwaway private test submission (just a
  `lakefile.toml` + `Submission.lean` proving `two_plus_two_eq_four`).
- `leanprover/comparator` — upstream comparator, which drives the
  landrun sandbox.
- `zouuup/landrun` — Go wrapper around Linux landlock.

### The comparator / landrun invocation

From
[comparator/Main.lean](https://github.com/leanprover/comparator/blob/master/Main.lean),
`safeLakeBuild` is what runs inside the sandbox:

```lean
runSandBoxed {
  cmd := "lake",
  args := #["build", target.toString (escape := false)],
  envPass := #["PATH", "HOME", "LEAN_ABORT_ON_PANIC"],
  envOverride := #[("LEAN_ABORT_ON_PANIC", some "1")],
  readablePaths := #[projectDir],
  writablePaths := #[dotLakeDir],
  executablePaths := #[leanPrefix, gitLocation],
}
```

`buildLandrunArgs` prepends a fixed prefix to every invocation:

```lean
#["--best-effort", "--ro", "/", "--rw", "/dev", "-ldd", "-add-exec"]
```

So the full command comparator runs for `Challenge` is approximately:

```
landrun --best-effort --ro / --rw /dev -ldd -add-exec \
  --env PATH --env HOME --env LEAN_ABORT_ON_PANIC \
  --ro <projectDir> \
  --rwx <projectDir>/.lake \
  --rox <leanPrefix> \
  --rox <gitLocation> \
  lake build Challenge
```

`projectDir` is comparator's `cwd` (set from `IO.currentDir` at the top of
`Main.lean`), which is whatever directory `lake env comparator config.json`
was invoked from. In our flow that's the overlaid workspace directory, and
comparator happily prints `Building Challenge` before invoking landrun.

### The flow on the workflow side

`.github/workflows/submission.yml` has three jobs: `fetch`, `evaluate`, `record`.

Only `evaluate` is relevant here. It:

1. runs `jlumbroso/free-disk-space` to make room for Mathlib
2. `actions/checkout@v4` the benchmark repo with `persist-credentials: false`
3. `rm -rf .git` (belt-and-braces: keep any persisted token out of untrusted Lean's reach)
4. `leanprover/lean-action@v1` with `use-mathlib-cache: true` (primes the repo-root `.lake/packages/mathlib`)
5. installs `landrun`, `lean4export`, `comparator` exactly the way `.github/workflows/ci.yml` does
6. downloads the submission tarball from the `fetch` job
7. runs `scripts/evaluate_submission.py` which:
   a. walks the submission for `lakefile.toml` files with a `name` matching a manifest problem id
   b. copies the pristine `generated/<id>/` workspace into `<repo>/.submission-*/workspaces/<id>/`
   c. overlays the submitter's `Submission.lean` and `Submission/**/*.lean`
   d. runs `lake update`, `lake exe cache get`, and **`lake build Challenge Solution Submission`** in the workspace, outside any sandbox, so comparator's sandboxed `lake build` should be a no-op
   e. invokes `lake exe lean-eval run-eval --json --problem <id> --workspaces-root ...` as a subprocess
8. `run-eval` scores problems by calling `run_problem_test`, which runs `lake test` inside each workspace
9. `lake test` → `workspace_test:exe` → `lake env comparator config.json`
10. comparator prints `Building Challenge`, invokes landrun, landrun denies

At step 10 the denial happens. **Every build step up to that point has run successfully, including the deliberately-thorough pre-build of `Challenge Solution Submission` in step 7d.**

### Evidence that the pre-build is effective

From CI run [24286278921](https://github.com/kim-em/lean-eval/actions/runs/24286278921)
(commit `484de8d`), evaluate step `Run evaluate_submission.py` stderr block:

```
--- lake build Challenge Solution Submission [rc=0] ---
stdout:
✔ [8264/8270] Built Submission.Helpers (383ms)
⚠ [8265/8270] Built Challenge (87s)
warning: Challenge.lean:3:8: declaration uses `sorry`
✔ [8267/8270] Built Submission (87s)
✔ [8269/8270] Built Solution (6.5s)
Build completed successfully (8270 jobs).
--- end lake build Challenge Solution Submission ---
```

Note: 87 seconds of real work to build both `Challenge` (whose proof is
`sorry`, as expected — the public statement) and `Submission` (the
submitter's `by decide` proof). `Solution` took 6.5s. After this step,
`<workspace>/.lake/build/lib/{Challenge,Solution,Submission}.olean` all
exist.

Then run-eval runs, and later in the same stderr block:

```
✔ [2/4] Built WorkspaceTest (2.6s)
✔ [3/4] Built WorkspaceTest:c.o (469ms)
✔ [4/4] Built workspace_test:exe (2.6s)
Building Challenge
[landrun:error] 2026/04/11 16:28:05 permission denied
uncaught exception: Child exited with 1
```

`Building Challenge` is printed by `safeLakeBuild` in comparator's
`Main.lean` **before** landrun starts. So comparator reached the
sandboxed-build step; the denial is from inside the sandbox.

### What ci.yml does, and that it's been broken

`.github/workflows/ci.yml` runs `scripts/check_comparator_installation.py`,
which is a minimal reproducer:

```python
with tempfile.TemporaryDirectory() as tmpdir:
    workspace = pathlib.Path(tmpdir) / "two_plus_two"
    shutil.copytree(source, workspace)
    solve_two_plus_two(workspace)  # replace sorry with norm_num
    run(["lake", "update"], cwd=workspace)
    run(["lake", "exe", "cache", "get"], cwd=workspace)
    run(["lake", "test"], cwd=workspace)
```

This is functionally identical to the part of `evaluate_submission.py` that
primes the workspace and then runs `lake test`. **It has been failing on
every `ci.yml` run on `main` for at least the last 100 runs.** I did not
introduce the problem; my investigation of the submission workflow just
surfaced it.

Whoever built the submission pipeline assumed this path worked because the
overall `ci.yml` job was being interpreted as green by something — it is
**not** green. Search for `Run Comparator Installation Checks` in recent
runs and you will see the step either never completes or fails with the
same `permission denied`.

## What has been tried, and what was ruled out

In rough chronological order, every one of these changed symptoms or made
things faster, but none fixed the landrun denial itself:

1. **Disk space.** Early runs hit "No space left on device" while unpacking
   a second copy of Mathlib's `.lake/packages/mathlib`. Fixed by adding
   `jlumbroso/free-disk-space@main` to the `evaluate` job. Strips Android,
   .NET, Haskell, docker images. Frees ~30 GB. Still needed.
2. **Workspace location.** Moved from `/tmp/...` to `<repo>/.submission-*/`
   so that `comparator`'s `projectDir` would be under the benchmark repo.
   No effect on the denial; the error is identical in both locations.
3. **Shared `.lake/packages` via symlink.** Symlinked each workspace's
   `.lake/packages` to `<repo>/.lake/packages` to avoid a second unpacked
   Mathlib. No effect; same denial. Reverted because it complicated the
   mental model without helping.
4. **Pre-building Challenge/Solution/Submission.** Added
   `lake build Challenge Solution Submission` to the priming step. The
   targets build successfully, `Challenge.olean` etc. exist on disk, and
   the sandboxed `lake build` ought to be a no-op — but the denial still
   happens at the same point.
5. **Priming order.** Ensured `lake update` and `lake exe cache get` run
   before any sandboxed lake invocation. Verified in workflow logs that
   they run to completion and populate `<workspace>/.lake/packages/`.
6. **Stdout pollution.** Incidental: `run_eval.py --json`'s stdout was
   being polluted by `lake build` progress from subprocesses it spawns,
   which made my JSON parse fail and hid the real error. Fixed by
   fd-level `dup2(stderr, stdout)` around the whole run-eval pipeline in
   `--json` mode. Not related to the landrun denial but needed for the
   diagnostics to be readable. See `run_eval.py:main` `_stdout_to_stderr`.
7. **Issue-to-mint ordering.** `actions/create-github-app-token@v1` without
   an explicit `owner` defaulted to the benchmark repo where the App was
   not installed. Fixed by extracting owner from the issue URL. Landed in
   commit `440dddc`. Not related to landrun.
8. **`permissions: {}` on evaluate.** Initially set on the `evaluate` job
   for maximum threat-model tightness. This broke `actions/checkout` with
   a 404 on a public repo (GITHUB_TOKEN had no `contents: read`). Relaxed
   to `permissions: { contents: read }` with `persist-credentials: false`
   on the checkout. `rm -rf .git` still runs before any lake step, so no
   token persists into the lake runtime.

## Hypotheses worth testing

In rough order of plausibility, given what I have seen:

1. **Lake is writing somewhere outside `.lake/`.** Candidates:
   - `~/.cache/lean` or `$HOME/.cache/...` — blocked because HOME is only
     `--env`-passed as a variable, not mapped as a writable path
   - `/tmp/...` scratch for lake's compilation pipeline
   - `<projectDir>/lake-manifest.json` mtime updates (file is inside
     `projectDir`, which is `--ro`)
   - A lock file or `.lake-lock` at the project root, outside `.lake/`
   - `/proc/self/...` or `/sys/...` writes that landlock rejects
2. **`--best-effort` is silently dropping an `--rwx` rule.** landrun's
   `--best-effort` mode falls back to less-restrictive behavior when
   landlock features are missing on the kernel, but might also silently
   skip rules whose paths don't exist at landrun start time. If
   `projectDir/.lake` does not exist at the time landrun is invoked (or
   is a symlink at that moment), the `--rwx` rule might be dropped
   entirely, leaving the whole filesystem `--ro`.
3. **`-ldd -add-exec` interaction.** These flags (undocumented in
   `landrun --help` as of this writing) look like they allow dynamic-
   linker resolution and executable-bit elevation. They may interact
   unexpectedly with the `--rox` / `--rwx` rules. Worth diffing landrun
   source to see what they actually do.
4. **Landlock LSM version mismatch.** The `ubuntu-latest` runner kernel
   may have a landlock ABI version that landrun (`v0.1.15`) or
   `go-landlock` (`v0.0.0-20250303204525-1544bccde3a3`) does not fully
   support. Worth checking `uname -r` on the runner and the minimum
   landlock ABI landrun requires.
5. **Lake reads/writes via a file descriptor opened before the landlock
   scope.** Landlock only controls new `openat` calls, not file
   descriptors inherited from before the restriction was applied. If
   lake's child process inherits an fd from the parent `lake env`
   invocation pointing at something outside `.lake/`, a later write
   through that fd might still succeed — but a later close/reopen would
   fail. This matters less for `permission denied` and more for understanding
   what's happening at the syscall level.
6. **The comparator prefix args have a typo/bug.** `--best-effort --ro /`
   followed later by `--ro <projectDir>` is probably fine, but the
   ordering of `--ro` and `--rwx` for paths that are subtrees of each
   other may behave unexpectedly. `projectDir/.lake` is a child of
   `projectDir` which is `--ro`, and also `<projectDir>/.lake` is a child
   of `/` which is also `--ro`. The `--rwx` for `.lake` needs to override
   both. Does it?

## What I would do next

### Near-term diagnostics

1. **Get landrun verbose output.** Landrun's default denial message has
   no path. Check `landrun --help` for any log-level flag, or
   `strace landrun ...` to see the `landlock_add_rule` syscalls and which
   paths they correspond to.
2. **Run the minimal repro under `strace -f -e openat,write,landlock_*`**
   on a linux box: symlink a generated workspace to `/tmp`, replace the
   sorry, run `lake update`, `lake exe cache get`, `lake test`. Watch for
   the failing syscall.
3. **Turn on `auditd` on the GitHub Actions runner.** Add to the workflow:
   ```yaml
   - name: Enable landlock audit
     run: |
       sudo apt-get install -y auditd
       sudo systemctl start auditd
       sudo auditctl -a always,exit -F arch=b64 -S openat -F exit=-EACCES
   ```
   then after the failing lake test, `sudo ausearch -k landlock` to get
   the denied path(s).
4. **Temporarily disable landrun.** Patch comparator's `runSandBoxed`
   to just `IO.Process.spawn` the inner command directly (no landrun).
   Confirm the rest of the pipeline works and produces a `succeeded:
   true` result for `two_plus_two`. That will at least let the dogfood
   record land while landrun debugging proceeds in parallel. **Do not
   ship this — it trivially defeats the sandbox — but it is a useful
   debugging step and confirms that everything else in the pipeline is
   correct.**
5. **Try `--ro` paths = `/`, `/usr`, `/opt`, `/home/runner`.** Instead of
   a single `--ro /`, explicitly whitelist only the system paths lake
   needs (elan toolchain, temp dirs). This may surface which path lake is
   actually touching that landrun rejects.

### Once root cause is known

Almost certainly the fix is either:

- a small patch to comparator adding one or two paths to `readablePaths`
  or `writablePaths` (e.g. `~/.cache/lean`, `/tmp/lake-*`, or
  `<projectDir>/lake-manifest.json` if it needs to be writable), or
- a landrun version bump and/or flag change to `buildLandrunArgs`, or
- a kernel-level fix on the runner image (unlikely; we don't control it).

## Pointers

### Files to look at

- `scripts/evaluate_submission.py` — in particular `_prime_workspace` and
  `overlay_match`; these are what the submission workflow runs before
  `run_eval`
- `scripts/check_comparator_installation.py` — the minimal reproducer that
  should be the simplest way to bisect this
- `scripts/run_eval.py` — runs `lake test` per workspace; see
  `run_problem_test`
- `.github/workflows/submission.yml` — the new three-job submission
  pipeline
- `.github/workflows/ci.yml` — the existing CI, which has been failing
  on this same issue
- upstream `comparator/Main.lean` on
  https://github.com/leanprover/comparator — `safeLakeBuild`,
  `runSandBoxed`, `buildLandrunArgs`

### Recent CI runs

Every run of the submission workflow that got past priming but failed on
comparator:

| run id | notes |
| --- | --- |
| [24284464953](https://github.com/kim-em/lean-eval/actions/runs/24284464953) | First run where the workspace landed under `<repo>/.submission-*/`. Disk full on Mathlib re-unpack. |
| [24284826623](https://github.com/kim-em/lean-eval/actions/runs/24284826623) | With free-disk-space. Lake update triggered inside the sandbox, first `permission denied`. |
| [24285100962](https://github.com/kim-em/lean-eval/actions/runs/24285100962) | With pre-build of Challenge/Solution/Submission added. Still `permission denied`. |
| [24285383774](https://github.com/kim-em/lean-eval/actions/runs/24285383774) | All three jobs green. Comparator reported `succeeded: false`. Leaderboard record not created because `passed: []`. |
| [24286278921](https://github.com/kim-em/lean-eval/actions/runs/24286278921) | With full stdout/stderr diagnostics. Same `Building Challenge → permission denied`. |

### Dogfood reproducer

The private dogfood repo has been prepared:
https://github.com/kim-em/lean-eval-dogfood . It is the minimal shape
a submission can take: `lakefile.toml` with
`name = "two_plus_two"`, `Submission.lean` with a real proof
(`theorem two_plus_two_eq_four : (2 : Nat) + 2 = 4 := by decide`). The
`lean-eval-bot` GitHub App is installed on it. Re-triggering the
submission workflow against it is the fastest feedback loop — toggle
the `submission` label on issue #1 of `kim-em/lean-eval`.

### Running the minimal reproducer outside CI

On a Linux machine with landrun installed (`go install
github.com/zouuup/landrun/cmd/landrun@latest`) and lean4 via elan:

```bash
git clone https://github.com/kim-em/lean-eval
cd lean-eval
lake exe cache get    # seed repo-root Mathlib
# build comparator and lean4export locally; add them to PATH
python3 scripts/check_comparator_installation.py
```

If this reproduces the denial locally, you have a tight debugging loop.
If it does not, the problem is specific to the GitHub Actions runner
environment (kernel, landlock ABI, filesystem layout).

## What must not regress when this is fixed

- `rm -rf .git` in the `evaluate` job stays. The threat model is that
  the submitter's Lean code is untrusted during `lake build` and must
  not see any persisted git token.
- `permissions: {contents: read}` only on `evaluate`. Do not grant
  `issues: write` or `contents: write` to that job.
- The three-job split with `LEADERBOARD_WRITE_TOKEN` in `record` only.
- The landrun sandbox itself. This file exists *because* the sandbox is
  non-negotiable for this project.
