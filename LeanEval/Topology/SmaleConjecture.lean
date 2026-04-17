import Mathlib.Geometry.Manifold.Diffeomorph
import Mathlib.Geometry.Manifold.Instances.Sphere
import Mathlib.Geometry.Manifold.Instances.Real
import Mathlib.Geometry.Manifold.IsManifold.InteriorBoundary
import Mathlib.LinearAlgebra.UnitaryGroup
import EvalTools.Markers

namespace LeanEval
namespace Topology

open scoped Manifold ContDiff
open Metric (sphere)

/-!
# Smale conjecture (Hatcher, 1983), relative parameterized form

Hatcher's theorem says the inclusion `O(4) ↪ Diff(S³)` (restriction of the linear action
on ℝ⁴) is a homotopy equivalence of topological spaces. Stating it in that form would
require mathlib to carry the C^∞ topology on `Diffeomorph S³ S³`, which it does not yet
have.

We state the equivalent **relative parameterized** form: for every compact smooth
manifold-with-boundary X and every smooth family of self-diffeomorphisms
`F : X × S³ → S³` whose restriction to `∂X × S³` already comes from a continuous map
`ψ_bdry : ∂X → O(4)` (acting by the linear action), there is a continuous extension
`ψ : X → O(4)` with `ψ|∂X = ψ_bdry` and a smooth isotopy rel `∂X` from `F` to the
family induced by `ψ`.

For `X = D^k`, `∂X = S^{k-1}`, this says `π_k(Diff(S³), O(4)) = 0` for all `k ≥ 0`,
which (modulo smoothing theory translating between smooth families parameterized by X
and continuous maps `X → Diff(S³)` with the C^∞ topology) is equivalent to
`O(4) ↪ Diff(S³)` being a homotopy equivalence.

The Cerf case `X = pt` (so `∂X = ∅`, the relative hypothesis is vacuous) is
Cerf's theorem Γ₄ = 0 (see `CerfGammaFour.lean`).

**Desired future improvement.** Once mathlib gains a C^∞ topology on `Diffeomorph M N`
(making it a topological group, with smooth families ↔ continuous maps into it), this
statement should be rewritten in the direct form: the continuous group homomorphism
`O(4) ↪ Diff(S³)` is a homotopy equivalence of topological spaces. Until then, the
relative parameterized form below is the most faithful statement available.
-/

/-- **Smale conjecture (Hatcher 1983), relative parameterized form.**
For every compact smooth manifold-with-boundary `X` and every smooth family `F` of
self-diffeomorphisms of `S³` parameterized by `X` whose boundary restriction already
factors through the linear action of `O(4)`, there is a smooth isotopy of `F`, rel
`∂X`, to a family fully factoring through `O(4)`. -/
@[eval_problem]
theorem smale_conjecture
    {n : ℕ} [NeZero n]
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
  sorry

end Topology
end LeanEval
