import Mathlib.Geometry.Manifold.Diffeomorph
import Mathlib.Geometry.Manifold.Instances.Sphere
import Mathlib.Geometry.Manifold.Instances.Real
import Mathlib.LinearAlgebra.UnitaryGroup
import EvalTools.Markers

namespace LeanEval
namespace Topology

open scoped Manifold ContDiff
open Metric (sphere)

/-!
# Cerf's theorem Γ₄ = 0 (1968)

Cerf's theorem states that every self-diffeomorphism of the standard 3-sphere is
smoothly isotopic to the restriction of a linear isometry of ℝ⁴ — equivalently,
the inclusion `O(4) ↪ Diff(S³)` (acting by restriction of the linear action on ℝ⁴) is
surjective on π₀. The classical name `Γ₄ = 0` refers to Cerf's group of pseudo-isotopies
in dimension 4 (originally formulated as the obstruction to extending self-diffeomorphisms
of S³ across D⁴).

This is the unparameterized (X = point) case of the Smale conjecture (Hatcher 1983, see
`SmaleConjecture.lean`). It is historically and technically distinct from the full Smale
conjecture: Cerf's original proof predates Hatcher's by 15 years and uses pseudo-isotopy
theory rather than the bigon / 2-sphere configuration analysis Hatcher employs.

We state isotopy as a smooth map `[0, 1] × S³ → S³` whose every time slice is a
diffeomorphism, witnessed by an explicit smooth slice-inverse `F'`. Smoothness of `F`
and `F'` together with the pointwise-inverse identities forces each time-slice
`p ↦ F(t, p)` to be a diffeomorphism (its slice-inverse `p ↦ F'(t, p)` is smooth as a
composition with the smooth inclusion `p ↦ (t, p)`). This avoids the need for a topology
on `Diffeomorph S³ S³` (which mathlib does not yet have).
-/

/-- **Cerf's theorem Γ₄ = 0.** Every self-diffeomorphism of S³ is smoothly isotopic to
the restriction of a linear isometry of ℝ⁴. -/
@[eval_problem]
theorem cerf_gamma_four
    (f : sphere (0 : EuclideanSpace ℝ (Fin 4)) 1 ≃ₘ⟮𝓡 3, 𝓡 3⟯
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
  sorry

end Topology
end LeanEval
