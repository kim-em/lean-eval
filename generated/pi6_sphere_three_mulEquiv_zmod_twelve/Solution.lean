import Mathlib
import Submission

theorem pi6_sphere_three_mulEquiv_zmod_twelve (x : Metric.sphere (0 : EuclideanSpace ℝ (Fin 4)) 1) :
    Nonempty
      (HomotopyGroup.Pi 6 (Metric.sphere (0 : EuclideanSpace ℝ (Fin 4)) 1) x ≃*
        Multiplicative (ZMod 12)) := by
  exact Submission.pi6_sphere_three_mulEquiv_zmod_twelve x
