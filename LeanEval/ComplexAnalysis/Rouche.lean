import Mathlib.Analysis.Complex.ValueDistribution.LogCounting.Basic
import EvalTools.Markers

namespace LeanEval
namespace ComplexAnalysis

open MeromorphicOn

/-!
Rouché's theorem, stated as equality of multiplicity-counted zero counts on a closed disk
centered at `0`.

The previous formulation used `ValueDistribution.logCounting f 0 R`, the **log-weighted**
Nevanlinna counting function — which is *not* the conclusion of Rouché. Under `‖g‖ < ‖f‖`
on the boundary, `f` and `f + g` have the same number of zeros (counted with multiplicity)
inside the disk, but the log-weighted count depends on where each zero sits. Concretely,
`f(z) = z` and `g(z) = -1/2` satisfy `|g| = 1/2 < 2 = |z| = |f|` on `|z| = 2`, yet
`logCounting f 0 2 = log 2` while `logCounting (f + g) 0 2 = log(2 / (1/2)) = log 4`.

We instead state the conclusion in terms of the multiplicity sum of the zero divisor
restricted to the closed disk of radius `R`, which is the standard form of Rouché.
-/

@[eval_problem]
theorem rouche_zero_count_eq
    {f g : ℂ → ℂ} {R : ℝ}
    (hR : 0 < R)
    (hf : MeromorphicOn f Set.univ)
    (hg : AnalyticOn ℂ g Set.univ)
    (hbound : ∀ z : ℂ, ‖z‖ = R → ‖g z‖ < ‖f z‖) :
    (∑ᶠ z, ((divisor (f + g) Set.univ)⁺.toClosedBall R) z) =
      (∑ᶠ z, ((divisor f Set.univ)⁺.toClosedBall R) z) := by
  sorry

end ComplexAnalysis
end LeanEval
