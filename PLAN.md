# PLAN

This file tracks the pieces that should be designed carefully rather than improvised.

## 1. Pin external versions

CI currently pulls several moving targets:

- `go install github.com/zouuup/landrun/cmd/landrun@main`
  (in both `ci.yml` and `submission.yml`)
- `jlumbroso/free-disk-space@main` (in `submission.yml`; `ci.yml` is on `@v1.3.1`)
- comparator and `lean4export` are not pinned to specific revisions

Pick concrete versions, pin them, and write down the upgrade procedure.

## 2. Native-Lean migration of lean-eval tooling

The leaderboard *site* is native Lean, but the lean-eval-side tooling that
produces the JSON it consumes is still Python:

- `scripts/generate_projects.py` — workspace generator
- `scripts/evaluate_submission.py` — evaluation driver
- `scripts/update_leaderboard.py` — result writer
- `scripts/validate_submission.py` — submission shape check
- `scripts/check_problem_build.py`, `check_generated_builds.py`,
  `fetch_submission.py`, `run_eval.py`, `start_problem.py`

Migrate the remaining scripts so the entire toolchain lives inside `lake`.

## 3. Problem curation

The repo currently ships ~33 workspaces across number theory, combinatorics,
topology, complex analysis, group theory, convex geometry, linear algebra,
algebraic geometry, differential geometry, and a couple of starter / hole
examples.

Open work:

- audit topic coverage and difficulty distribution (we are already past the
  original 15–25 problem target, so the question is which problems are
  carrying their weight)
- decide whether any problems are too easy or saturated by current frontier
  models and should be retired or replaced
- continue adding problems where we identify gaps
