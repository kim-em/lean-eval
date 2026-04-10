import Mathlib
import Submission.Helpers

namespace Submission

theorem pi_succ_sphere_n_mulEquiv_zmod_two (n : ℕ) (hn : 3 ≤ n)
    (x : Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 1))) 1) :
    Nonempty
      (HomotopyGroup.Pi (n + 1) (Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 1))) 1) x ≃*
        Multiplicative (ZMod 2)) := by
  sorry

end Submission
