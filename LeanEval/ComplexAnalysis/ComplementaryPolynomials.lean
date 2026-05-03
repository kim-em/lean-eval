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

The previous statement asked for `Q.natDegree = P.natDegree` (strict equality), which fails on
the boundary case `P = X`: there `|P(z)| = 1` on the entire unit circle, so any complementary `Q`
must vanish on the circle and hence be the zero polynomial; but `natDegree 0 = 0 ≠ 1 = natDegree X`.
We relax the constraint to `≤`, which is what Fejér-Riesz / spectral factorization actually
delivers (the degree of `Q` is at most that of `P`, with equality generically).
-/

/-- If `P` is bounded by `1` on the unit circle, then there is a polynomial `Q` of degree at most
that of `P` whose squared moduli complement `P` to `1` on the unit circle. -/
@[eval_problem]
theorem exists_complementary_polynomial_on_unit_circle
    (P : ℂ[X])
    (hP : ∀ z : Circle, ‖P.eval (z : ℂ)‖ ≤ 1) :
    ∃ Q : ℂ[X],
      Q.natDegree ≤ P.natDegree ∧
        ∀ z : Circle, ‖P.eval (z : ℂ)‖ ^ 2 + ‖Q.eval (z : ℂ)‖ ^ 2 = 1 := by
  sorry

end ComplexAnalysis
end LeanEval
