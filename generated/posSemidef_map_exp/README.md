# `posSemidef_map_exp`

Entrywise exponential of a PSD matrix is PSD

- Problem ID: `posSemidef_map_exp`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Part of the Schur-Polya-Loewner theory of entrywise functions preserving PSD. The proof uses the Schur product theorem iteratively: exp_⊙(A) = ∑ A^{⊙k}/k!, each Hadamard power is PSD, and the convergent series of PSD matrices is PSD.
- Source: I.J. Schoenberg, Positive definite functions on spheres, 1942.
- Informal solution: Write exp(a_{ij}) as the convergent series ∑ (a_{ij})^k / k!. The matrix with entries (a_{ij})^k is the k-fold Hadamard product A^{⊙k}, which is PSD by iterated Schur product. The partial sums are nonneg combinations of PSD matrices, hence PSD. PSD is a closed condition, so the limit is PSD.

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
