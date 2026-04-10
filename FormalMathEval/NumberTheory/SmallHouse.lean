import Mathlib.NumberTheory.NumberField.Cyclotomic.Basic
import Mathlib.NumberTheory.NumberField.House
import EvalTools.Markers

namespace FormalMathEval
namespace NumberTheory

open NumberField

/-!
Theorem 1.0.5 from Calegari--Morrison--Snyder, "Cyclotomic integers, fusion
categories, and subfactors" (`arXiv:1004.0665`).

Mathlib's `NumberField.house` is exactly the "largest absolute value of all
conjugates" appearing in the paper, so we use it directly.
-/

@[eval_problem]
theorem cyclotomic_integer_house_le_two
    {K : Type*} [Field K] [NumberField K] [Algebra ℚ K]
    (n : ℕ) [NeZero n] [IsCyclotomicExtension {n} ℚ K] {β : K}
    (hβ_int : IsIntegral ℤ β)
    (hβ_real : β ∈ NumberField.maximalRealSubfield K) :
    house β ≤ 2 →
      house β = 2 ∨ ∃ m : ℕ, 0 < m ∧ house β = 2 * Real.cos (Real.pi / m) := by
  sorry

@[eval_problem]
theorem cyclotomic_integer_house_between_two_and_76_33
    {K : Type*} [Field K] [NumberField K] [Algebra ℚ K]
    (n : ℕ) [NeZero n] [IsCyclotomicExtension {n} ℚ K] {β : K}
    (hβ_int : IsIntegral ℤ β)
    (hβ_real : β ∈ NumberField.maximalRealSubfield K) :
    (2 < house β ∧ house β < (76 : ℝ) / 33) →
      house β = (7 + Real.sqrt 3) / 2 ∨
      house β = Real.sqrt 5 ∨
      house β = 1 + 2 * Real.cos (2 * Real.pi / 7) ∨
      house β = (1 + Real.sqrt 5) / Real.sqrt 2 ∨
      house β = (1 + Real.sqrt 13) / 2 := by
  sorry

end NumberTheory
end FormalMathEval
