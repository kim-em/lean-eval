import Mathlib.Analysis.InnerProductSpace.Laplacian
import Mathlib.FieldTheory.Separable
import Mathlib.LinearAlgebra.Charpoly.Basic
import Mathlib.Topology.EMetricSpace.BoundedVariation
import Mathlib.Topology.MetricSpace.Lipschitz
import EvalTools.Markers

namespace LeanEval
namespace Analysis
namespace PDE

/-!
# Total variation stability of viscous hyperbolic systems

This file proves a stability estimate for solutions to the equation
$$u_t + A(u)u_x = u_xx$$, where $$A(u)$$ is an `n` by `n` strictly hyperbolic
matrix (i.e., it has `n` distinct real eigenvalues) which depends smoothly on $$u$$.

The estimate, first proved in [1, Theorem 1], estimates the total variation of a solution at any time `t > 0`
in terms of the variation at the initial time (provided the initial variation is small).
Since the variation is invariant under spatial rescaling, the estimate is
uniform in the strength of the diffusion coefficient (which we take to be one for simplicity).
This allows to prove that vanishing viscosity approximations for hyperbolic conservation
laws converge to the entropy solutions.

* [1]. Bianchini and Bressan, Vanishing viscosity solutions of nonlinear hyperbolic systems. Annals of Mathematics 161 (2005).
-/
open Filter Topology Set Function Bornology
open scoped NNReal Nat EReal ContDiff

local notation:arg "ℝ^" n:arg => EuclideanSpace ℝ (Fin n)

variable (n : ℕ) (A : ℝ^n → (ℝ^n →L[ℝ] ℝ^n)) (K : Set ℝ^n)

/-- `A` is (uniformly, smoothly) hyperbolic on `K` if `A` is smooth,
and for every `x ∈ K` it holds that `A x` has `n` real distinct eigenvalues. -/
structure IsHyperbolicOn : Prop where
  smooth : ContDiff ℝ ∞ A
  real_ev x (hx : x ∈ K) : (A x).charpoly.Splits
  distinct_ev x (hx : x ∈ K) : (A x).charpoly.Separable

/-- `u` is a global smooth solution if `u` is continuous for all `t` and `x`, smooth for
`t > 0` and solves the PDE in the classical sense for `t > 0`. -/
structure IsSmoothGlobalSolution (u : ℝ → ℝ → (ℝ^n)) : Prop where
  diff : ContDiffOn ℝ ∞ (uncurry u) (Set.Ioi 0 ×ˢ Set.univ)
  cont : ∀ n ≤ 2, ∀ t > 0, UniformContinuousOn (uncurry fun s x ↦ iteratedDeriv n (u s · ) x) (Icc 0 t ×ˢ univ)
  bdd : ∀ n ≤ 2, ∀ t > 0, IsBounded <| (uncurry (fun s x ↦ iteratedDeriv n (u s · ) x)) '' (Icc 0 t ×ˢ univ)
  pde : ∀ t > 0, ∀ x, (deriv (u · x) t) + A (u t x) (deriv (u t ·) x) = iteratedDeriv 2 (u t ·) x

/-- A total variation estimate holds if the total variation of any smooth solution
at time `t > 0` can be linearly estimated in terms of the total variation at time `0`,
provided the variation at time `0` is sufficiently small and the initial left limit of `u`
lies in `K` (see [1, Theorem 1]).
-/
structure HasTVEstimateWith (δ C : EReal) : Prop where
  estimate u (h_sol : IsSmoothGlobalSolution n A u)
      (h_initial_tv : eVariationOn (u 0 ·) univ ≤ δ)
      (h_initial_lim : ∃ x ∈ K, Tendsto (u 0 ·) atBot (𝓝 x))
      t (ht : t > 0) : eVariationOn (u t ·) univ ≤ C * eVariationOn (u 0 ·) univ

/-- Total variation estimate for hyperbolic systems -/
@[eval_problem]
theorem hyperbolic_viscosity (hn : 1 ≤ n) (hK : IsCompact K) (h : IsHyperbolicOn n A K) :
    ∃ δ > 0, ∃ C < ⊤, HasTVEstimateWith n A K δ C := by
  sorry

end PDE
end Analysis
end LeanEval
