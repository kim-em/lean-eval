# `symplectic_matrix_det`

Symplectic matrices have determinant 1

- Problem ID: `symplectic_matrix_det`
- Group: `formalization-evaluation`
- Status: `archived`
- Visible: yes
- Statement Revision: 1
- Tags: none
- Submitter: Kim Morrison
- Notes: §39 of Oliver Knill's 'Some Fundamental Theorems in Mathematics'. For any commutative ring R and 2n × 2n symplectic matrix A over R (A * J * Aᵀ = J with J = [[0, -I], [I, 0]]), det A = 1. Taking determinants of AᵀJA = J only forces (det A)² = 1; the sign requires the Pfaffian argument. Mathlib has `Matrix.symplecticGroup` and proves `symplectic_det` (IsUnit (det A)). When the problem was written (Mathlib rev 5450b53e5ddc) the equals-1 claim was an explicit TODO in Mathlib/LinearAlgebra/SymplecticGroup.lean. Mathlib PR #40352 (merged 2026-07-07) added `SymplecticGroup.det_eq_one` with this statement, and the toolchain bump of 2026-07-29 brought it into the pinned Mathlib; since then the hole closes by `exact SymplecticGroup.det_eq_one _hA`.
- Source: Folklore (Pfaffian computation). Listed as §39 in O. Knill, Some Fundamental Theorems in Mathematics (https://people.math.harvard.edu/~knill/graphgeometry/papers/fundamental.pdf). Formalized in Mathlib as `SymplecticGroup.det_eq_one` (Mathlib PR #40352, merged 2026-07-07); previously marked as an open TODO at the head of Mathlib/LinearAlgebra/SymplecticGroup.lean (rev 5450b53e5ddc).
- Informal solution: Apply the Pfaffian: for any 2n × 2n matrix M and antisymmetric 2n × 2n matrix Ω, Pf(Mᵀ Ω M) = det(M) · Pf(Ω). With Ω = J (so Pf(J) ≠ 0) and Aᵀ J A = J for A ∈ Sp_{2n}(R), one gets Pf(J) = det(A) · Pf(J), hence det A = 1. (This requires the Pfaffian for matrices over a commutative ring R; the construction is purely algebraic.)

Do not modify `Challenge.lean` or `Solution.lean`. Those files are part of the
trusted benchmark and fixed by the repository.

Write your solution in `Submission.lean` and any additional local modules under
`Submission/`.

Participants may use declarations from the existing Mathlib imports. Broadening
the import header (especially to `import Mathlib`) can change elaboration of the
fixed statement; any added import must leave `lake build Solution` green. Helper
code not available through compatible imports must be inlined into the workspace.

Multi-file submissions are allowed through `Submission.lean` and additional local
modules under `Submission/`.

`lake test` runs comparator for this problem. The command expects a comparator
binary in `PATH`, or in the `COMPARATOR_BIN` environment variable.
