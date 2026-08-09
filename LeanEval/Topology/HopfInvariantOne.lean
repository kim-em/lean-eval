import Mathlib
import EvalTools.Markers

namespace LeanEval.Topology.HopfInvariantOne

/-!
# Hopf invariant one: the spheres that are H-spaces

Adams' Hopf-invariant-one theorem, in its H-space formulation: the sphere
`𝕊ⁿ` admits an H-space structure if and only if `n` is `0`, `1`, `3`, or `7`.

We use Mathlib's `HSpace`: a continuous multiplication with a basepoint `e`
satisfying `μ (e, e) = e` strictly and two-sided units up to based homotopy.
The reverse direction transports the multiplications on the unit spheres of
the reals, complexes, quaternions, and octonions; the forward direction is
Adams' theorem.
-/

/-- **Adams' Hopf-invariant-one theorem** (H-space form). The sphere `𝕊ⁿ`
admits an H-space structure if and only if `n = 0`, `1`, `3`, or `7`. -/
@[eval_problem]
theorem hSpace_sphere_iff (n : ℕ) :
    Nonempty (HSpace (Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 1))) 1)) ↔
      n = 0 ∨ n = 1 ∨ n = 3 ∨ n = 7 := by
  sorry

end LeanEval.Topology.HopfInvariantOne
