# `substInv_X_sub_X_sq_eq_catalan`

Catalan generating function via compositional inversion

- Problem ID: `substInv_X_sub_X_sq_eq_catalan`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: The compositional inverse of X - X² is the generating function for Catalan numbers. This is a classical application of Lagrange inversion in enumerative combinatorics, connecting formal power series inversion to Dyck paths, binary trees, and triangulations.
- Source: E. Catalan, Note sur une équation aux différences finies, 1838; J.-L. Lagrange, Nouvelle méthode pour résoudre les équations littérales, 1770.
- Informal solution: The compositional inverse C(x) satisfies C - C² = x, giving C = (1 - √(1-4x))/2. By the binomial series, its coefficients are the Catalan numbers C_n = (2n choose n)/(n+1).

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
