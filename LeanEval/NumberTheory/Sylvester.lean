import Mathlib
import EvalTools.Markers

/-!
# Sylvester's conjecture

Every prime number congruent to 4, 7 or 8 modulo 9 is the sum of two rational cubes.
In fact squares of such primes are also the sum of two rational cubes.
The proof uses Heegner points and Rankin–Selberg L-functions.

## References

* Hongbo Yin. A proof of the 4,7 cases of Sylvester’s conjecture on cube sums. https://arxiv.org/abs/2605.25917
* Ashay Burungale, Ye Tian. A proof of Sylvester's conjecture. https://arxiv.org/abs/2609.14893
* http://arxiv.org/abs/2304.09806 is an earlier but problematic claim, see https://x.com/samit_dasgupta/status/2100283036088606910.
-/

namespace LeanEval.NumberTheory

@[eval_problem]
theorem sylvester (p : ℕ) (h : p.Prime) (h' : p % 9 ∈ ({4, 7, 8} : Set ℕ)) :
    (∃ a b : ℚ, p = a ^ 3 + b ^ 3) ∧ (∃ a b : ℚ, p ^ 2 = a ^ 3 + b ^ 3) := by
  sorry

end LeanEval.NumberTheory
