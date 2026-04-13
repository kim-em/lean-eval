import Mathlib.Analysis.Matrix.Order
import EvalTools.Markers

namespace FormalMathEval
namespace LinearAlgebra

open scoped MatrixOrder Matrix

/-!
Oppenheim's inequality (1930).

For positive semidefinite matrices `A` and `B`, the determinant of the Hadamard (entrywise)
product satisfies `det(A) · ∏ᵢ B_{ii} ≤ det(A ⊙ B)`. This strengthens the Schur product
theorem, which only asserts that `A ⊙ B` is positive semidefinite.
-/

@[eval_problem]
theorem oppenheim_inequality
    {n : Type*} [Fintype n] [DecidableEq n]
    {A B : Matrix n n ℝ} (hA : A.PosSemidef) (hB : B.PosSemidef) :
    A.det * ∏ i, B i i ≤ (A ⊙ B).det := by
  sorry

end LinearAlgebra
end FormalMathEval
