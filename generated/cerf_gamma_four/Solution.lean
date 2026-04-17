import Mathlib
import Submission

open scoped Manifold ContDiff
open Metric (sphere)

theorem cerf_gamma_four (f : sphere (0 : EuclideanSpace ℝ (Fin 4)) 1 ≃ₘ⟮𝓡 3, 𝓡 3⟯
         sphere (0 : EuclideanSpace ℝ (Fin 4)) 1) :
    ∃ (A : Matrix.orthogonalGroup (Fin 4) ℝ)
      (F F' : unitInterval × sphere (0 : EuclideanSpace ℝ (Fin 4)) 1 →
              sphere (0 : EuclideanSpace ℝ (Fin 4)) 1),
      ContMDiff ((𝓡∂ 1).prod (𝓡 3)) (𝓡 3) ∞ F ∧
      ContMDiff ((𝓡∂ 1).prod (𝓡 3)) (𝓡 3) ∞ F' ∧
      (∀ t p, F  (t, F' (t, p)) = p) ∧
      (∀ t p, F' (t, F  (t, p)) = p) ∧
      (∀ p, F (0, p) = f p) ∧
      (∀ p, (F (1, p) : EuclideanSpace ℝ (Fin 4)) =
            Matrix.UnitaryGroup.toLinearEquiv A
              (p : EuclideanSpace ℝ (Fin 4))) := by
  exact Submission.cerf_gamma_four f
