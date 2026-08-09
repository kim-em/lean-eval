import Mathlib
import EvalTools.Markers

namespace LeanEval.NumberTheory.WeakGoldbach

/-!
# Weak Goldbach theorem

Helfgott's weak (or ternary) Goldbach theorem states that every odd natural
number greater than `5` is a sum of three primes. The primes need not be
distinct; in particular, the least case is `7 = 2 + 2 + 3`.
-/

/-- **Weak Goldbach theorem.** Every odd natural number greater than `5` is a
sum of three primes, with repetition allowed. -/
@[eval_problem]
theorem weak_goldbach (n : ℕ) (hn : 5 < n) (hodd : Odd n) :
    ∃ p q r : ℕ, p.Prime ∧ q.Prime ∧ r.Prime ∧ n = p + q + r := by
  sorry

end LeanEval.NumberTheory.WeakGoldbach
