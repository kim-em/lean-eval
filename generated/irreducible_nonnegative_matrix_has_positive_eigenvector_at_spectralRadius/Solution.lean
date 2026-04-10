import Mathlib
import Submission

open scoped NNReal

theorem irreducible_nonnegative_matrix_has_positive_eigenvector_at_spectralRadius {n : Type*} [Fintype n] [DecidableEq n]
    (A : Matrix n n ℝ)
    (hA : A.IsIrreducible) :
    ∃ v : n → ℝ,
      Module.End.HasEigenvector (Matrix.toLin' A) (spectralRadius ℝ A).toReal v ∧
      (∀ i, 0 < v i) := by
  exact @Submission.irreducible_nonnegative_matrix_has_positive_eigenvector_at_spectralRadius n _ _ A hA
