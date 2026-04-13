import Mathlib.RingTheory.PowerSeries.Substitution
import Mathlib.Data.Nat.Choose.Central
import EvalTools.Markers

namespace FormalMathEval
namespace Combinatorics

open PowerSeries

/-!
The Catalan generating function via compositional inversion.

The Catalan numbers `C_n = (2n choose n) / (n + 1)` arise as the coefficients of the
compositional inverse of the power series `X - X²`. This is one of the most classical
applications of Lagrange inversion in enumerative combinatorics: the generating function
`C(x) = ∑ C_n x^{n+1}` satisfies `C(x) - C(x)² = x`, so `C` is the compositional inverse
of the polynomial `P(x) = x - x²`.

Equivalently, `C(x) = (1 - √(1 - 4x)) / 2`.

This identity connects formal power series inversion (`substInv`) to the enumeration of
Dyck paths, binary trees, triangulations of polygons, and many other combinatorial structures.
-/

@[eval_problem]
theorem substInv_X_sub_X_sq_eq_catalan (n : ℕ) :
    haveI : Invertible (coeff 1 ((X : ℚ⟦X⟧) - X ^ 2)) := by
      simp [coeff_X, coeff_X_pow]; exact invertibleOne
    coeff (n + 1) (substInv ((X : ℚ⟦X⟧) - X ^ 2)) =
      (Nat.choose (2 * n) n : ℚ) / (↑n + 1) := by
  sorry

end Combinatorics
end FormalMathEval
