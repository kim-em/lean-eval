import ChallengeDeps

open LeanEval.Analysis.PDE
open Filter Topology Set Function Bornology
open scoped NNReal Nat EReal ContDiff

local notation:arg "ℝ^" n:arg => EuclideanSpace ℝ (Fin n)
variable (n : ℕ) (A : ℝ^n → (ℝ^n →L[ℝ] ℝ^n)) (K : Set ℝ^n)

theorem hyperbolic_viscosity (hn : 1 ≤ n) (hK : IsCompact K) (h : IsHyperbolicOn n A K) :
    ∃ δ > 0, ∃ C < ⊤, HasTVEstimateWith n A K δ C := by
  sorry
