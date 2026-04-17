import Mathlib
import Submission

open scoped Manifold ContDiff
open Metric (sphere)

theorem smale_conjecture {n : ℕ} [NeZero n]
    (X : Type) [TopologicalSpace X] [T2Space X] [SecondCountableTopology X]
    [ChartedSpace (EuclideanHalfSpace n) X] [IsManifold (𝓡∂ n) ∞ X]
    [CompactSpace X]
    (F F' : X × sphere (0 : EuclideanSpace ℝ (Fin 4)) 1 →
            sphere (0 : EuclideanSpace ℝ (Fin 4)) 1)
    (hF  : ContMDiff ((𝓡∂ n).prod (𝓡 3)) (𝓡 3) ∞ F)
    (hF' : ContMDiff ((𝓡∂ n).prod (𝓡 3)) (𝓡 3) ∞ F')
    (hFinv₁ : ∀ x p, F  (x, F' (x, p)) = p)
    (hFinv₂ : ∀ x p, F' (x, F  (x, p)) = p)
    (ψ_bdry : (𝓡∂ n).boundary X → Matrix.orthogonalGroup (Fin 4) ℝ)
    (hψ_bdry_cont : Continuous ψ_bdry)
    (hF_bdry : ∀ (b : (𝓡∂ n).boundary X)
                 (p : sphere (0 : EuclideanSpace ℝ (Fin 4)) 1),
              (F ((b : X), p) : EuclideanSpace ℝ (Fin 4)) =
                Matrix.UnitaryGroup.toLinearEquiv (ψ_bdry b)
                  (p : EuclideanSpace ℝ (Fin 4))) :
    ∃ (ψ : X → Matrix.orthogonalGroup (Fin 4) ℝ)
      (H H' : X × unitInterval × sphere (0 : EuclideanSpace ℝ (Fin 4)) 1 →
              sphere (0 : EuclideanSpace ℝ (Fin 4)) 1),
      Continuous ψ ∧
      (∀ b : (𝓡∂ n).boundary X, ψ (b : X) = ψ_bdry b) ∧
      ContMDiff ((𝓡∂ n).prod ((𝓡∂ 1).prod (𝓡 3))) (𝓡 3) ∞ H ∧
      ContMDiff ((𝓡∂ n).prod ((𝓡∂ 1).prod (𝓡 3))) (𝓡 3) ∞ H' ∧
      (∀ x t p, H  (x, t, H' (x, t, p)) = p) ∧
      (∀ x t p, H' (x, t, H  (x, t, p)) = p) ∧
      (∀ x p, H (x, 0, p) = F (x, p)) ∧
      (∀ x (p : sphere (0 : EuclideanSpace ℝ (Fin 4)) 1),
              (H (x, 1, p) : EuclideanSpace ℝ (Fin 4)) =
              Matrix.UnitaryGroup.toLinearEquiv (ψ x)
                (p : EuclideanSpace ℝ (Fin 4))) ∧
      (∀ (b : (𝓡∂ n).boundary X)
         (t : unitInterval)
         (p : sphere (0 : EuclideanSpace ℝ (Fin 4)) 1),
              H ((b : X), t, p) = F ((b : X), p)) := by
  exact Submission.smale_conjecture X F F' hF hF' hFinv₁ hFinv₂ ψ_bdry hψ_bdry_cont hF_bdry
