# `cubic_decay_asymptotic`

Polynomial decay rate of y' = -y^3

- Problem ID: `cubic_decay_asymptotic`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Asymptotic rate y t * sqrt t -> 1/sqrt 2 for the unique solution of y' = -y^3 on (0, infty) with y continuous at 0 and y 0 = 1.
- Source: Standard ODE textbook exercise.
- Informal solution: The closed form is y(t) = (1 + 2t)^{-1/2}, so y(t) sqrt(t) = sqrt(t / (1 + 2t)) -> 1/sqrt(2). Uniqueness on (0, infty) follows by Grönwall: any two solutions u, v of u' = -u^3 with the same right-limit 1 at 0 satisfy |u - v|' bounded by a Lipschitz constant on bounded subintervals, and continuity at 0 forces |u(t) - v(t)| -> 0 as t -> 0+, hence u = v.

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
