# `oppenheim_inequality`

Oppenheim's inequality for Hadamard products

- Problem ID: `oppenheim_inequality`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Oppenheim's 1930 inequality: for PSD matrices A, B, det(A ⊙ B) ≥ det(A) · ∏ᵢ Bᵢᵢ. Uses the Schur product theorem (newly formalized) as a key ingredient.
- Source: I. Schur, Bemerkungen zur Theorie der beschränkten Bilinearformen, 1911; A. Oppenheim, Inequalities connected with definite Hermitian forms, 1930.
- Informal solution: Use induction on the matrix size, extracting a Schur complement at each step and applying the Schur product theorem to bound the determinant.

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
