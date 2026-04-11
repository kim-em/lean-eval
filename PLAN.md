# PLAN

This file tracks the pieces that should be designed carefully rather than improvised in the
first scaffold pass.

## High-Priority Next Decisions

### 1. Private Submission Service

The user asked to start at the "private submissions from day one" model instead of a
public-only workflow.

We need to design:

- how users authenticate
- whether submissions arrive as private GitHub repos, patch bundles, or uploaded tarballs
- how the service pins the benchmark base commit
- how private evaluation workers are isolated
- what proof artifacts are retained
- what public metadata appears on the leaderboard

Recommended direction:

- start with GitHub-based private submissions against a pinned public base commit
- require a commit SHA and a repository URL or installation-based access
- evaluate in an isolated worker that checks changed files before any Lean build occurs
- publish only score, model name, submission timestamp, and an optional paper/repo link

### 2. Generator Output

The generator emits one independent problem workspace per problem under `generated/`, and
those workspaces are checked into the repo. Each workspace contains:

- `Challenge.lean`
- `ChallengeDeps.lean`
- `Solution.lean`
- `Submission.lean`
- `Submission/Helpers.lean`
- `config.json`
- `lakefile.toml`
- `lean-toolchain`
- `WorkspaceTest.lean`
- `README.md`

`lake test` invokes comparator; that is the canonical score check.

Open questions:

- Should we also generate a one-command "single problem starter repo" tarball or template,
  beyond the existing `lake exe lean-eval start-problem` copy?
- Should we expose a faster local pre-check in addition to comparator?

### 3. Leaderboard Site

We need a static or mostly-static leaderboard that supports:

- overall score
- solved-count view
- per-problem breakdown
- links to source and informal solution
- model metadata
- submission history

Open questions:

- static site generated from JSON, or a thin dynamic frontend backed by a database?
- should failed private submissions remain entirely invisible, or show aggregate stats?

Recommended direction:

- JSON results artifacts checked into a separate public results repo or branch
- static site generated from those artifacts

## Problem Curation

We should curate an initial batch of roughly 15 to 25 problems with:

- broad topic coverage
- statements already expressible in Mathlib
- clear references
- optional informal proof links
- difficulty high enough that current frontier models do not saturate the benchmark

Candidate families to investigate:

- concrete algebra and number theory statements
- equivalence theorems where the statement is compact but the formalization is nontrivial
- results with published formalization-adjacent proofs that help humans but do not make the
  Lean proof trivial

The repository currently contains ~17 problems across number theory, combinatorics,
topology, complex analysis, group theory, convex geometry, and linear algebra, plus the
trivial starter `two_plus_two`. Further curation should fill gaps in topic coverage and
difficulty distribution.

## Immediate Follow-Up Work

### Repo Scaffolding

- add result schemas for per-problem and per-submission outputs
- extend CI beyond the current repository health checks as the submission pipeline lands
- continue migrating operational tooling from Python scripts to native Lean so manifest
  validation, generation, submission checks, and scoring live inside the Lean toolchain
  rather than behind Python wrappers (the `@[eval_problem]` attribute and manifest parser
  are already native; generator, builder, and scorer are still Python shell-outs)

### UX

- decide whether participants work directly in this repo or in generated per-problem repos
  when submitting (local workflow via `lake exe lean-eval start-problem` already exists)

### Trust / Security

- specify exactly when untrusted files may be read or built
- pin comparator, `lean4export`, and `landrun` versions
- decide whether we want optional nanoda checking enabled by default
- document the exact threat model for the hosted submission service
