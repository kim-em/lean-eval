import Mathlib.Analysis.Complex.ValueDistribution.LogCounting.Basic
import EvalTools.Markers

namespace FormalMathEval
namespace ComplexAnalysis

open ValueDistribution

/-!
Rouché's theorem, stated here as equality of zero-counting functions on a circle centered at `0`.

The hypotheses are intentionally phrased in terms of the existing meromorphic/analytic and
`ValueDistribution.logCounting` APIs.
-/

@[eval_problem]
theorem rouche_logCounting_zero_eq
    {f g : ℂ → ℂ} {R : ℝ}
    (hR : 1 ≤ R)
    (hf : Meromorphic f)
    (hg : AnalyticOn ℂ g Set.univ)
    (hbound : ∀ z : ℂ, ‖z‖ = R → ‖g z‖ < ‖f z‖) :
    logCounting (f + g) 0 R = logCounting f 0 R := by
  sorry

end ComplexAnalysis
end FormalMathEval
