import Mathlib
import Submission

theorem pi_sphere_infinite_iff (k n : ℕ) (hn : 1 ≤ n)
    (x : Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 1))) 1) :
    Infinite (HomotopyGroup.Pi k (Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 1))) 1) x) ↔
      k = n ∨ (Even n ∧ k + 1 = 2 * n) := by
  exact Submission.pi_sphere_infinite_iff k n hn x
