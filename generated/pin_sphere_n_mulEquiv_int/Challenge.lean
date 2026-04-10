import Mathlib

theorem pin_sphere_n_mulEquiv_int (n : ℕ)
    (x : Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 2))) 1) :
    Nonempty
      (HomotopyGroup.Pi (n + 1) (Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 2))) 1) x ≃*
        Multiplicative ℤ) := by
  sorry
