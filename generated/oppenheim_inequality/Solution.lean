import Mathlib
import Submission

open scoped MatrixOrder Matrix

theorem oppenheim_inequality {n : Type*} [Fintype n] [DecidableEq n]
    {A B : Matrix n n ℝ} (hA : A.PosSemidef) (hB : B.PosSemidef) :
    A.det * ∏ i, B i i ≤ (A ⊙ B).det := by
  exact Submission.oppenheim_inequality hA hB
