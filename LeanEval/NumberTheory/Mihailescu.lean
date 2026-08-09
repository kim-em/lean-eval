import Mathlib
import EvalTools.Markers

namespace LeanEval.NumberTheory.Mihailescu

/-!
# Mihăilescu's theorem

Mihăilescu's theorem, formerly Catalan's conjecture, says that `8` and `9` are
the only consecutive nontrivial perfect powers. The equation below is written
with addition rather than natural-number subtraction, whose result is truncated
at zero.
-/

/-- **Mihăilescu's theorem (formerly Catalan's conjecture).** The only
consecutive nontrivial perfect powers are `2 ^ 3 = 8` and `3 ^ 2 = 9`. -/
@[eval_problem]
theorem mihailescu
    {x y m n : ℕ}
    (hx : 0 < x) (hy : 0 < y) (hm : 1 < m) (hn : 1 < n)
    (h : x ^ m = y ^ n + 1) :
    x = 3 ∧ y = 2 ∧ m = 2 ∧ n = 3 := by
  sorry

end LeanEval.NumberTheory.Mihailescu
