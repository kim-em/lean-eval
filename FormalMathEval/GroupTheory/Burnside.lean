import Mathlib.GroupTheory.Solvable
import Mathlib.Data.Nat.Prime.Basic
import EvalTools.Markers

namespace FormalMathEval
namespace GroupTheory

/-!
Burnside's `p^a q^b` theorem.

Mathlib already contains solvability infrastructure, so the statement is naturally phrased as
`IsSolvable G` for a finite group of order `p ^ a * q ^ b`.
-/

@[eval_problem]
theorem finite_group_isSolvable_of_card_eq_prime_pow_mul_prime_pow
    {G : Type*} [Group G] [Fintype G]
    {p q a b : ℕ}
    (hp : Nat.Prime p)
    (hq : Nat.Prime q)
    (hpq : p ≠ q)
    (hcard : Fintype.card G = p ^ a * q ^ b) :
    IsSolvable G := by
  sorry

end GroupTheory
end FormalMathEval
