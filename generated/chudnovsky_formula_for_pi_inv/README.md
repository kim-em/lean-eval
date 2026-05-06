# `chudnovsky_formula_for_pi_inv`

Chudnovsky formula for pi inverse

- Problem ID: `chudnovsky_formula_for_pi_inv`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Uses the existing Mathlib definition of the Chudnovsky series and asks for the missing identity with pi inverse. The Chudnovsky formula states 1/π = (12 / 640320^(3/2)) · ∑_{n=0}^∞ (-1)^n · (6n)! · (545140134·n + 13591409) / ((3n)! · (n!)^3 · 640320^(3n)).
- Source: https://arxiv.org/abs/1809.00533
- Informal solution: Prove that the Chudnovsky series 1/π = (12 / 640320^(3/2)) · ∑_{n=0}^∞ (-1)^n · (6n)! · (545140134·n + 13591409) / ((3n)! · (n!)^3 · 640320^(3n)) holds, e.g. following Milla's detailed complex-analytic proof.

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
