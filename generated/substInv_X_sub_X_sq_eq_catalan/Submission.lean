import Mathlib
import Submission.Helpers

open PowerSeries

namespace Submission

theorem substInv_X_sub_X_sq_eq_catalan (n : ℕ) :
    haveI : Invertible (coeff 1 ((X : ℚ⟦X⟧) - X ^ 2)) := by
  sorry

end Submission
