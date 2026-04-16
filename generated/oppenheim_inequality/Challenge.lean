import Mathlib

open scoped MatrixOrder Matrix

theorem oppenheim_inequality {n : Type*} [Fintype n] [DecidableEq n]
    {A B : Matrix n n ℝ} (hA : A.PosSemidef) (hB : B.PosSemidef) :
    A.det * ∏ i, B i i ≤ (A ⊙ B).det := by
  sorry
