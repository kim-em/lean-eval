# `linear_ode_asymptotic_stability`

Linear ODE with negative-real-part eigenvalues is asymptotically stable

- Problem ID: `linear_ode_asymptotic_stability`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: If every eigenvalue of A has negative real part, every solution of x' = Ax decays to zero in norm.
- Source: Classical linear stability theory; Hirsch-Smale-Devaney.
- Informal solution: Pass to the complexification; bring A to (Schur or Jordan) upper-triangular form; the matrix exponential satisfies ||exp(tA)|| <= C(1+t^{n-1}) exp(alpha t) for any alpha greater than the maximum real part of the spectrum, hence decays to 0. For any t_1 > 0, x(t) = exp((t - t_1) A) x(t_1) for t >= t_1 by uniqueness of the linear IVP, so ||x(t)|| -> 0 as t -> infty.

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
