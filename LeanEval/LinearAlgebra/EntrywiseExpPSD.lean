import Mathlib.Analysis.Matrix.Order
import Mathlib.Analysis.SpecialFunctions.ExpDeriv
import EvalTools.Markers

namespace LeanEval
namespace LinearAlgebra

open scoped MatrixOrder Matrix

/-!
The entrywise exponential of a positive semidefinite matrix is positive semidefinite.

This is a consequence of the Schur product theorem (Schur 1911) and the Taylor expansion
of the exponential function. The key idea is that `exp_⊙(A)_{ij} = exp(a_{ij})` can be
written as the convergent series `∑ₖ (1/k!) A^{⊙k}`, where `A^{⊙k}` denotes the k-fold
Hadamard product. Each `A^{⊙k}` is positive semidefinite by iterated application of the
Schur product theorem, and a convergent nonnegative combination of PSD matrices is PSD.

This result is part of the Schur–Pólya–Loewner theory of entrywise functions preserving
positive semidefiniteness, with applications in statistics (correlation matrices) and
quantum information theory (density matrices).
-/

@[eval_problem]
theorem posSemidef_map_exp
    {n : Type*} [Fintype n] [DecidableEq n]
    {A : Matrix n n ℝ} (hA : A.PosSemidef) :
    (A.map Real.exp).PosSemidef := by
  sorry

end LinearAlgebra
end LeanEval
