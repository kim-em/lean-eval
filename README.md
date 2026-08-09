# Lean Eval

**[View the leaderboard →](https://lean-lang.org/eval/)**

This repository is a comparator-based Lean benchmark for formal mathematics.
Benchmark authors write trusted problem statements once in shared Lean modules, and the
tooling generates one comparator workspace per problem under `generated/`.

A submission is scored entirely by comparator results: a problem counts as solved iff
comparator accepts the submitted solution.

The main user-facing entrypoint is:

```bash
lake exe lean-eval --help
```

## Quick Start For Benchmark Problem Contributors

Use this path if you are adding or editing benchmark problems.

### 1. Install and fetch dependencies

```bash
lake exe cache get
lake build
```

### 2. Add or edit a trusted theorem

Put the statement in one of the shared modules under `LeanEval/` and mark it with
`@[eval_problem]`.

```lean
@[eval_problem]
theorem my_new_problem : ... := by
  sorry
```

Current source modules live in topic folders such as:

- `LeanEval/NumberTheory/`
- `LeanEval/Topology/`
- `LeanEval/ComplexAnalysis/`
- `LeanEval/EasyProblems.lean`

### 3. Add the manifest entry

Each tagged declaration must be listed by exactly one file under
[`manifests/problems/`](manifests/problems/). One file per problem,
named `<id>.toml`, with top-level keys (no `[[problem]]` wrapper). The
filename stem must match the `id` field. The `holes` array names every
`@[eval_problem]`-tagged declaration in the module that the problem
owns; for the common single-theorem case it has one element.

```toml
# manifests/problems/my_new_problem.toml
id = "my_new_problem"
title = "My new problem"
test = false
module = "LeanEval.SomeModule"
holes = ["my_new_problem"]
submitter = "Your Name"
notes = "Optional notes."
source = "Optional citation or URL."
informal_solution = "Optional proof sketch or reference."
```

The required fields are:

- `id` (must equal the filename stem)
- `title`
- `test`
- `module`
- `holes`
- `submitter`

The one-file-per-problem layout means two PRs adding distinct problems
never conflict on the manifest.

The manifest is the only entry point CI has into `LeanEval/`, so a module
no manifest names is never built. `validate-manifest` therefore rejects any
`.lean` file under `LeanEval/` that is neither named by some `module` field
nor imported (directly or transitively) by a module that is, and rejects any
file in `manifests/problems/` that is not a `.toml`.

#### Multi-hole problems

A problem may bundle several `def`s, `instance`s and `theorem`s — list
them all in `holes`. Comparator then asks the participant to fill every
listed declaration in their `Submission.lean`. Two conventions:

- **Name every instance.** The generator addresses holes by their
  declaration name, and Lean's auto-generated names for anonymous
  `instance`s (e.g. `instTopologicalSpaceJacobian`) are not stable. Use
  `instance instAddCommGroup : ... := sorry` rather than `instance : ...
  := sorry`.
- **Use `holes` even for one declaration.** There is no `theorem = "..."`
  shorthand; a singleton hole is just `holes = ["my_thm"]`.

See [`LeanEval/Sandbox/DefHoleExample.lean`](LeanEval/Sandbox/DefHoleExample.lean)
and [`LeanEval/Sandbox/InstanceHoleExample.lean`](LeanEval/Sandbox/InstanceHoleExample.lean)
for the smallest working examples, or
[`LeanEval/Geometry/JacobianChallenge.lean`](LeanEval/Geometry/JacobianChallenge.lean)
for a realistic multi-hole problem.

### 4. Validate the authored source of truth (optional)

```bash
lake exe lean-eval validate-manifest
lake exe lean-eval check-problem-build
```

`validate-manifest` checks that `@[eval_problem]` declarations and manifest entries
match, and that no module under `LeanEval/` escapes the manifest's reach.
`check-problem-build` builds the problem modules so warning-producing Lean changes
do not slip through. Both catch the most common mistakes before a CI roundtrip;
on a clean checkout, validating the full problem inventory can take some time.

### 5. Open a PR

That's it — push your branch and open a PR. CI regenerates the comparator workspaces
under `generated/` and verifies they build, so you do not need to commit anything
under `generated/` yourself. Once the PR merges, a separate workflow regenerates
`generated/` on `main` and pushes the result.

If CI fails with a generation or build error, you'll need to fix the source. The
fastest local equivalent is:

```bash
lake exe lean-eval generate --problem my_new_problem
lake exe lean-eval check-generated-builds --problem my_new_problem
```

## Quick Start For Solvers

Use this path if you want to prove benchmark problems without touching the trusted
benchmark files.

### 1. Pick a problem

Generated workspaces live under `generated/`, one directory per problem. The current
catalog is summarized in [`generated/index.json`](/home/kim/lean-evals/generated/index.json).

Examples:

- `generated/two_plus_two/`
- `generated/list_append_singleton_length/`
- `generated/cyclotomic_integer_house_le_two/`

### 2. Create your local workspace

Copy a clean starter workspace:

```bash
lake exe lean-eval start-problem two_plus_two
```

That creates `workspaces/two_plus_two/` by default. You can also pass a destination:

```bash
lake exe lean-eval start-problem two_plus_two /tmp/two_plus_two
```

### 3. Install workspace dependencies

```bash
cd workspaces/two_plus_two
lake update
```

### 4. Write your proof

Solver-owned files are:

- `Submission.lean`
- `Submission/Helpers.lean`
- any additional Lean files you add under `Submission/`

Trusted files you should not edit in the normal solver workflow are:

- `Challenge.lean`
- `Solution.lean`
- `config.json`
- `lakefile.toml`

`Challenge.lean` contains the benchmark statement. `Solution.lean` is the fixed bridge
that tells comparator to check your theorem from the `Submission` namespace.

### 5. Run comparator locally

```bash
lake test
```

`lake test` shells out to four external tools that you must install yourself:
`landrun` (the sandbox), `lean4export` (exports oleans to text), `comparator`
(the verifier), and `nanoda` (the independent kernel). `WorkspaceTest` forces
comparator to replay every Solution through nanoda, so a missing `nanoda_bin`
fails the check. All four are pinned to immutable commits; the authoritative
pin table lives in [`SECURITY.md`](SECURITY.md) ("Trusted dependencies and pin
policy"), and CI installs exactly these in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml). Reproduce that setup
locally:

```bash
# landrun — install at the pinned commit (NOT @main; the version string is
# unreliable, and tagged releases through v0.1.15 lack fixes comparator needs).
go install github.com/zouuup/landrun/cmd/landrun@5ed4a3db3a4ad930d577215c6b9abaa19df7f99f
export PATH="$(go env GOPATH)/bin:$PATH"

# lean4export — clone, check out the pin, and build.
lean_eval_root="$(pwd)"  # run this setup from the lean-eval repository root
git clone https://github.com/leanprover/lean4export.git
( cd lean4export
  git checkout 4e7915201d3f9f04470d9eae002fa695f7cdc589
  cp "$lean_eval_root/lean-toolchain" lean-toolchain
  lake build lean4export )
export PATH="$PWD/lean4export/.lake/build/bin:$PATH"

# comparator — clone, check out the pin (adds `def`-hole support), and build.
git clone https://github.com/leanprover/comparator.git
( cd comparator
  git checkout 71b52ec29e06d4b7d882726553b1ceb99a2499e0
  lake build comparator )
export PATH="$PWD/comparator/.lake/build/bin:$PATH"

# nanoda — the external kernel. WorkspaceTest forces comparator to replay the
# Solution through nanoda, so `lake test` fails unless `nanoda_bin` is on your
# PATH. Needs a Rust toolchain (`cargo`); the pin is on the source commit, not
# the compiler version.
git clone https://github.com/robsimmons/nanoda_lib.git
( cd nanoda_lib
  git checkout 68d5ca9db226849b41a6fff59d796ff19d0a8840
  cargo build --release )
export PATH="$PWD/nanoda_lib/target/release:$PATH"
```

`lean4export` and `comparator` are Lean programs. The pinned lean4export source
uses Lean v4.32.0 by default, but its build command above deliberately selects
the workspace's exact toolchain by copying `lean-toolchain`; Lean v4.32.0 and v4.32.2
have incompatible olean headers. Comparator builds `Challenge.olean` with the
workspace toolchain and then reads it back with `lean4export`, so exact
compatibility is required. If the formats differ you get
`failed to read file '.../Challenge.olean', incompatible header` — that error
means a Lean/olean version mismatch (or a stale `.lake` artifact left over from
an earlier toolchain), never a problem with your proof. If you hit it, rebuild
`lean4export` at the pinned commit after copying this repository's
`lean-toolchain` into its checkout, rebuild comparator at its pinned commit, and clear the affected
workspace's `.lake/build` before retrying.

Once the tools are on your `PATH`, verify the whole pipeline against the starter
problem before attempting a real one — this builds and scores `two_plus_two` end
to end, so it isolates an install problem from a proof problem:

```bash
lake exe lean-eval check-comparator-installation
```

If you keep the comparator binary somewhere off your `PATH`, point `lake test` at
it explicitly (`landrun` and `lean4export` must still be on `PATH`, since
comparator invokes them):

```bash
COMPARATOR_BIN=/path/to/comparator lake test
```

### 6. Check your local score

From the repo root:

```bash
lake exe lean-eval run-eval
lake exe lean-eval run-eval --json
```

The scorer prefers `workspaces/<problem-id>/` when present and falls back to
`generated/<problem-id>/` otherwise.

## Submission Rules

To **submit a solution** to the public leaderboard, open a submission issue on
the submissions repository:

> **[github.com/leanprover/lean-eval-submissions](https://github.com/leanprover/lean-eval-submissions)**

That repository owns the hosted submission pipeline and the stored results.
This repository (`leanprover/lean-eval`) holds only the problem set and the
comparator/sandbox integration.

Participants may use Mathlib freely.

If a proof needs helper code that is not already in Mathlib, that code must be included
inside the submission workspace itself. Multi-file submissions are allowed through
`Submission.lean` and extra local modules under `Submission/`.

For benchmark-repo submissions (a PR that edits a `generated/` workspace in place),
validate changed paths with:

```bash
lake exe lean-eval validate-submission --file generated/two_plus_two/Solution.lean
```

The current validator accepts:

- modifications to `generated/<problem-id>/Solution.lean` and
  `generated/<problem-id>/Submission.lean`
- additions, modifications, deletions, renames, or copies of `.lean` files under
  `generated/<problem-id>/Submission/`
- additions (only) of markdown files anywhere inside
  `generated/<problem-id>/`, other than the generated `README.md`
- additions (only) of a top-level `generated/<problem-id>/LICENCE` or
  `generated/<problem-id>/LICENSE` file

In practice, solvers should normally work in `Submission.lean` and `Submission/`.

## Repository Layout

- [`LeanEval/`](/home/kim/lean-evals/LeanEval): trusted authored problem statements
- [`manifests/problems/`](manifests/problems/): one TOML file per problem, named `<id>.toml`
- [`generated/`](/home/kim/lean-evals/generated): generated comparator workspaces
- [`scripts/`](/home/kim/lean-evals/scripts): generation, validation, and scoring helpers
- [`PLAN.md`](/home/kim/lean-evals/PLAN.md): deferred design and roadmap notes

## End-To-End Repo Checks

For a local health pass over the repository:

```bash
lake exe lean-eval validate-manifest
lake exe lean-eval check-problem-build
lake exe lean-eval generate --check
lake exe lean-eval check-generated-builds
lake exe lean-eval run-eval
```

There is also an end-to-end workflow self-check:

```bash
lake exe lean-eval check-eval-workflow
```
