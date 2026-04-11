import Mathlib
import Submission

theorem finite_group_isSolvable_of_card_eq_prime_pow_mul_prime_pow {G : Type*} [Group G] [Fintype G]
    {p q a b : ℕ}
    (hp : Nat.Prime p)
    (hq : Nat.Prime q)
    (hpq : p ≠ q)
    (hcard : Fintype.card G = p ^ a * q ^ b) :
    IsSolvable G := by
  exact Submission.finite_group_isSolvable_of_card_eq_prime_pow_mul_prime_pow hp hq hpq hcard
