import Mathlib
import Submission

open Metric

theorem deBranges (f : ℂ → ℂ) (diff : DifferentiableOn ℂ f (ball 0 1)) (inj : (ball 0 1).InjOn f)
    (h0 : f 0 = 0) (h1 : deriv f 0 = 1) (n : ℕ) : ‖iteratedDeriv n f 0 / n.factorial‖ ≤ n := by
  exact Submission.deBranges f diff inj h0 h1 n
