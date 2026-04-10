# `chudnovsky_formula_for_pi_inv`

Chudnovsky formula for pi inverse

- Problem ID: `chudnovsky_formula_for_pi_inv`
- Test Problem: no
- Author: Kim Morrison
- Notes: Uses the existing Mathlib definition of the Chudnovsky series and asks for the missing identity with pi inverse.
- Source: https://link.springer.com/article/10.1007/s40316-018-0102-6
- Informal solution: Evaluate the Chudnovsky series and prove that it sums to 1 / pi.

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
