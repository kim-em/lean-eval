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

Each tagged declaration must be listed by exactly one entry in
[`manifests/problems.toml`](manifests/problems.toml). The `holes` array
names every `@[eval_problem]`-tagged declaration in the module that the
problem owns; for the common single-theorem case it has one element.

```toml
[[problem]]
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

- `id`
- `title`
- `test`
- `module`
- `holes`
- `submitter`

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
match. `check-problem-build` builds the problem modules so warning-producing Lean changes
do not slip through. Both are cheap and catch the most common mistakes before a CI
roundtrip.

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

If the comparator binary is not on your `PATH`, set it explicitly:

```bash
COMPARATOR_BIN=/path/to/comparator lake test
```

You can verify the installation against the starter problem from the repo root with:

```bash
lake exe lean-eval check-comparator-installation
```

Comparator setup also requires the upstream external tools, including `landrun` and
`lean4export`. Install `landrun` from its git `main` branch
(`go install github.com/zouuup/landrun/cmd/landrun@main`); the latest tagged
release (v0.1.15) is missing fixes that comparator's sandbox relies on.

CI pins `lean4export` to tag `v4.30.0-rc2` and `comparator` to commit
`71b52ec29e06d4b7d882726553b1ceb99a2499e0` (which adds support for
`def`-shaped holes).

### 6. Check your local score

From the repo root:

```bash
lake exe lean-eval run-eval
lake exe lean-eval run-eval --json
```

The scorer prefers `workspaces/<problem-id>/` when present and falls back to
`generated/<problem-id>/` otherwise.

## Submission Rules

Participants may use Mathlib freely.

If a proof needs helper code that is not already in Mathlib, that code must be included
inside the submission workspace itself. Multi-file submissions are allowed through
`Submission.lean` and extra local modules under `Submission/`.

For benchmark-repo submissions, validate changed paths with:

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
- [`manifests/problems.toml`](/home/kim/lean-evals/manifests/problems.toml): problem metadata
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
