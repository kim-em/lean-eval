import Mathlib.Algebra.Polynomial.Basic
import Mathlib.Analysis.Complex.Circle
import EvalTools.Markers

namespace LeanEval
namespace ComplexAnalysis

open Polynomial

/-!
Complementary polynomials on the unit circle.

This is the basic existence statement appearing in quantum signal processing: if a complex
polynomial has sup norm at most `1` on the unit circle, then it admits a complementary polynomial
whose squared moduli add up to `1` on the circle.
-/

/-- If `P` is bounded by `1` on the unit circle, then there is a polynomial `Q` of the same degree
whose squared moduli complement `P` to `1` on the unit circle. -/
@[eval_problem]
theorem exists_complementary_polynomial_on_unit_circle
    (P : ℂ[X])
    (hP : ∀ z : Circle, ‖P.eval (z : ℂ)‖ ≤ 1) :
    ∃ Q : ℂ[X],
      Q.natDegree = P.natDegree ∧
        ∀ z : Circle, ‖P.eval (z : ℂ)‖ ^ 2 + ‖Q.eval (z : ℂ)‖ ^ 2 = 1 := by
  sorry

end ComplexAnalysis
end LeanEval
