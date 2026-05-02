import Mathlib.Analysis.Complex.Circle
import Mathlib.Geometry.Manifold.Instances.Real
import EvalTools.Markers

/-!
Benchmark statements for topological classification of compact connected surfaces with boundary.

The representative surface in each homeomorphism class is obtained by
gluing certain arcs in the boundary of the unit disc.

Reference: Jean Gallier & Dianna Xu, *A Guide to the Classification Theorem for Compact Surfaces*,
Definition 6.5, Lemma 6.1, Theorem 6.1.
https://www.cis.upenn.edu/~jean/surfclassif-root.pdf
-/

namespace Complex

/-- The closed unit disc in the complex plane. -/
abbrev ClosedUnitDisc : Type := Metric.closedBall (0 : ℂ) 1

/-- The boundary point exp(2πir) on the boundary of the closed unit disc in the complex plane. -/
noncomputable def ClosedUnitDisc.bdyPtOfReal (r : ℝ) : ClosedUnitDisc :=
  ⟨r.fourierChar, r.fourierChar.2.le⟩

end Complex

namespace LeanEval.Topology.ClassificationOfSurfaces

open Complex Set

/-- The representative orientable surface homeomorphic to a closed orientable genus `p`
surface with `n` discs removed, obtained by identifying the boundary of a disc in the pattern
`a₁b₁a₁⁻¹b₁⁻¹⋯aₚbₚaₚ⁻¹bₚ⁻¹c₁h₁c₁⁻¹⋯cₙhₙcₙ⁻¹`. -/
inductive OrientableRel (p n : ℕ) : ClosedUnitDisc → ClosedUnitDisc → Prop
  | a (x : Icc (0 : ℝ) 1) (i : Fin p) : OrientableRel p n
      (.bdyPtOfReal <| (4 * i + x) / (4 * p + 3 * n))
      (.bdyPtOfReal <| (4 * i + 3 - x) / (4 * p + 3 * n))
  | b (x : Icc (0 : ℝ) 1) (i : Fin p) : OrientableRel p n
      (.bdyPtOfReal <| (4 * i + 1 + x) / (4 * p + 3 * n))
      (.bdyPtOfReal <| (4 * i + 4 - x) / (4 * p + 3 * n))
  | c (x : Icc (0 : ℝ) 1) (i : Fin n) : OrientableRel p n
      (.bdyPtOfReal <| - (3 * i + x) / (4 * p + 3 * n))
      (.bdyPtOfReal <| - (3 * i + 3 - x) / (4 * p + 3 * n))

/-- The representative non-orientable surface homeomorphic to a direct sum of `p` projective
planes with `n` discs removed, obtained by identifying the boundary of a disc in the pattern
`a₁a₁⋯aₚaₚc₁h₁c₁⁻¹⋯cₙhₙcₙ⁻¹`. -/
inductive NonOrientableRel (p n : ℕ) : ClosedUnitDisc → ClosedUnitDisc → Prop
  | a (x : Icc (0 : ℝ) 1) (i : Fin p) : NonOrientableRel p n
      (.bdyPtOfReal <| (2 * i + x) / (2 * p + 3 * n))
      (.bdyPtOfReal <| (2 * i + 1 + x) / (2 * p + 3 * n))
  | c (x : Icc (0 : ℝ) 1) (i : Fin n) : NonOrientableRel p n
      (.bdyPtOfReal <| -(3 * i + x) / (2 * p + 3 * n))
      (.bdyPtOfReal <| -(3 * i + 3 - x) / (2 * p + 3 * n))

open scoped Manifold

@[eval_problem]
theorem classification_of_surfaces (S : Type*) [TopologicalSpace S]
    [T2Space S] [ConnectedSpace S] [CompactSpace S]
    [ChartedSpace (EuclideanHalfSpace 2) S] [IsManifold (𝓡∂ 2) 0 S] :
    Nonempty (S ≃ₜ Metric.sphere (0 : EuclideanSpace ℝ (Fin 3)) 1) ∨
    ∃ p n, ((1 ≤ p ∨ 1 ≤ n) ∧ Nonempty (S ≃ₜ Quot (OrientableRel p n))) ∨
      (1 ≤ p ∧ Nonempty (S ≃ₜ Quot (NonOrientableRel p n))) := by
  sorry

end LeanEval.Topology.ClassificationOfSurfaces
