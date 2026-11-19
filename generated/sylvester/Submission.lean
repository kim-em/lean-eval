import Mathlib
import Submission.Helpers

namespace Submission

theorem sylvester (p : ℕ) (h : p.Prime) (h' : p % 9 ∈ ({4, 7, 8} : Set ℕ)) :
    (∃ a b : ℚ, p = a ^ 3 + b ^ 3) ∧ (∃ a b : ℚ, p ^ 2 = a ^ 3 + b ^ 3) := by
  sorry

end Submission
