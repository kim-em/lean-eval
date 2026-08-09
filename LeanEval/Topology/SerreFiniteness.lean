import Mathlib
import EvalTools.Markers

namespace LeanEval.Topology.SerreFiniteness

/-!
# Serre finiteness for homotopy groups of spheres

Serre's finiteness theorem: for `n ≥ 1` the homotopy group `πₖ(𝕊ⁿ)` is
infinite in exactly two situations: `k = n`, where it is `ℤ`, and
`k = 2 * n - 1` for even `n`, where it is `ℤ` plus a finite group. In every
other degree `πₖ(𝕊ⁿ)` is finite.

We state this as an if-and-only-if characterization of infinitude, with the
explicit-basepoint conventions of `LeanEval.Topology.HomotopyGroups`. The
exceptional degree `k = 2 * n - 1` is phrased as `k + 1 = 2 * n` to avoid
truncated natural-number subtraction.
-/

/-- **Serre finiteness.** For `n ≥ 1`, the homotopy group `πₖ(𝕊ⁿ)` is
infinite if and only if `k = n`, or `n` is even and `k = 2 * n - 1`. -/
@[eval_problem]
theorem pi_sphere_infinite_iff
    (k n : ℕ) (hn : 1 ≤ n)
    (x : Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 1))) 1) :
    Infinite (HomotopyGroup.Pi k (Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 1))) 1) x) ↔
      k = n ∨ (Even n ∧ k + 1 = 2 * n) := by
  sorry

end LeanEval.Topology.SerreFiniteness
