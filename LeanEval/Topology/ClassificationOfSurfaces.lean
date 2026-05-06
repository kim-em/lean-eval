import Mathlib.Geometry.Manifold.Instances.Real
import LeanEval.Topology.Prelude
import EvalTools.Markers

/-!
Benchmark statement for topological classification of compact connected surfaces with boundary.

Reference: Jean Gallier & Dianna Xu, *A Guide to the Classification Theorem for Compact Surfaces*,
Definition 6.5, Lemma 6.1, Theorem 6.1.
https://www.cis.upenn.edu/~jean/surfclassif-root.pdf
-/

namespace LeanEval.Topology

open Surface

@[eval_problem]
theorem classification_of_surfaces (S : Type*) [TopologicalSpace S]
    [T2Space S] [ConnectedSpace S] [CompactSpace S]
    [ChartedSpace (EuclideanHalfSpace 2) S] :
    Nonempty (S ≃ₜ Metric.sphere (0 : EuclideanSpace ℝ (Fin 3)) 1) ∨
    ∃ p n, ((1 ≤ p ∨ 1 ≤ n) ∧ Nonempty (S ≃ₜ OrientableRepr p n)) ∨
      (1 ≤ p ∧ Nonempty (S ≃ₜ NonOrientableRepr p n)) := by
  sorry

end LeanEval.Topology
