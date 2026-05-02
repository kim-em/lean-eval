# `bvp_comparison`

Comparison principle for the Dirichlet BVP

- Problem ID: `bvp_comparison`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: 1D maximum principle: -u'' <= -v'' on (0,1) and u <= v at the endpoints implies u <= v on [0,1].
- Source: Standard maximum-principle argument; Protter-Weinberger.
- Informal solution: From -u'' <= -v'' we get (u - v)'' >= 0 on (0, 1), so u - v is convex on [0, 1] (using continuity at the endpoints). A convex function lies below its chord, which here is non-positive at both endpoints, so u - v <= chord <= 0. A perturbation form: psi := (u - v) - delta x (1 - x) is strictly convex (psi'' >= 2 delta > 0) and attains its supremum at the boundary, where psi <= 0; let delta -> 0+.

Do not modify `Challenge.lean` or `Solution.lean`. Those files are part of the
trusted benchmark and fixed by the repository.

Write your solution in `Submission.lean` and any additional local modules under
`Submission/`.

Participants may use Mathlib freely. Any helper code not already available in
Mathlib must be inlined into the submission workspace.

Multi-file submissions are allowed through `Submission.lean` and additional local
modules under `Submission/`.

`lake test` runs comparator for this problem. The command expects a comparator
binary in `PATH`, or in the `COMPARATOR_BIN` environment variable.
