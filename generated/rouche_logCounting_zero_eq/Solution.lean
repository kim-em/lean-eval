import Mathlib
import Submission

open ValueDistribution

theorem rouche_logCounting_zero_eq {f g : ℂ → ℂ} {R : ℝ}
    (hR : 1 ≤ R)
    (hf : Meromorphic f)
    (hg : AnalyticOn ℂ g Set.univ)
    (hbound : ∀ z : ℂ, ‖z‖ = R → ‖g z‖ < ‖f z‖) :
    logCounting (f + g) 0 R = logCounting f 0 R := by
  exact @Submission.rouche_logCounting_zero_eq _ R hR hf hg hbound
