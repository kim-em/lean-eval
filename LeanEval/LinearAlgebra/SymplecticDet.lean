import Mathlib
import EvalTools.Markers

namespace LeanEval
namespace LinearAlgebra

/-!
# Symplectic matrices have determinant 1

§39 of Oliver Knill's *Some Fundamental Theorems in Mathematics*. For any
commutative ring `R` and `2n × 2n` symplectic matrix `A` over `R` (i.e.
`A * J * Aᵀ = J` with `J = [[0, -I], [I, 0]]`), one has `det A = 1`.

Taking determinants of `Aᵀ J A = J` only forces `(det A)² = 1`; the sign
requires the Pfaffian argument (`det A = Pf(Aᵀ J A) / Pf(J) = 1`).

mathlib has `Matrix.symplecticGroup l R` and `symplectic_det`
(`IsUnit (det A)`). When this problem was written the determinant-equals-one
claim was an open TODO in `Mathlib/LinearAlgebra/SymplecticGroup.lean`.
Mathlib PR #40352 (merged 2026-07-07) added `SymplecticGroup.det_eq_one`,
which is this statement, and the pinned Mathlib has included it since the
toolchain bump of 2026-07-29. The hole is therefore a library lookup.
-/

open Matrix

/-- **Symplectic matrices have determinant 1.** For any commutative ring `R`
and `2n × 2n` symplectic matrix `A` over `R`, `A.det = 1`. -/
@[eval_problem]
theorem symplectic_matrix_det
    {l R : Type*} [DecidableEq l] [Fintype l] [CommRing R]
    {A : Matrix (l ⊕ l) (l ⊕ l) R} (_hA : A ∈ Matrix.symplecticGroup l R) :
    A.det = 1 := by
  sorry

end LinearAlgebra
end LeanEval
