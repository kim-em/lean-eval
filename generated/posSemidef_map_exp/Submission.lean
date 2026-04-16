import Mathlib
import Submission.Helpers

open scoped MatrixOrder Matrix

namespace Submission

theorem posSemidef_map_exp {n : Type*} [Fintype n] [DecidableEq n]
    {A : Matrix n n ℝ} (hA : A.PosSemidef) :
    (A.map Real.exp).PosSemidef := by
  sorry

end Submission
