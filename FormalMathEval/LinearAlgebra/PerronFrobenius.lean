import Mathlib.Analysis.Normed.Algebra.Spectrum
import Mathlib.LinearAlgebra.Eigenspace.Basic
import Mathlib.LinearAlgebra.Matrix.Irreducible.Defs
import EvalTools.Markers

namespace FormalMathEval
namespace LinearAlgebra

open scoped NNReal

/-!
A Perron-Frobenius style statement for irreducible nonnegative real matrices.

Mathlib already exposes irreducibility of nonnegative matrices via `Matrix.IsIrreducible`, and
spectral radius via `spectralRadius`.
-/

@[eval_problem]
theorem irreducible_nonnegative_matrix_has_positive_eigenvector_at_spectralRadius
    {n : Type*} [Fintype n] [DecidableEq n]
    (A : Matrix n n ℝ)
    (hA : A.IsIrreducible) :
    ∃ v : n → ℝ,
      Module.End.HasEigenvector (Matrix.toLin' A) (spectralRadius ℝ A).toReal v ∧
      (∀ i, 0 < v i) := by
  sorry

end LinearAlgebra
end FormalMathEval
