# `dirichlet_eigenvalues_eq_nat_sq`

Dirichlet eigenvalues of -y'' = lambda y on [0,pi] are n^2

- Problem ID: `dirichlet_eigenvalues_eq_nat_sq`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Characterises the spectrum of the Dirichlet Laplacian on [0,pi]: lambda is an eigenvalue iff lambda = n^2 for some positive natural n.
- Source: Classical Sturm-Liouville theory.
- Informal solution: Case-split on the sign of lambda. For lambda <= 0 only the zero solution satisfies both boundary conditions. For lambda > 0 the general solution is A sin(sqrt lambda x) + B cos(sqrt lambda x); the boundary conditions force B = 0 and sqrt lambda in N_{>0}. Conversely, for lambda = n^2 with n in N_{>0}, the function sin(n x) is a nontrivial Dirichlet eigenfunction.

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
