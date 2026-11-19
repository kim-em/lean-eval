import Mathlib
import EvalTools.Markers

/-!
# Non-compact Riemann surfaces are equilaterally triangulable

Bishop, C.J., Rempe, L. Non-compact Riemann surfaces are equilaterally triangulable.
Invent. math. 244, 1–43 (2026). https://doi.org/10.1007/s00222-025-01375-4 https://arxiv.org/abs/2103.16702
-/

namespace LeanEval.Geometry.EquilateralTriangulation

/-- The model space for Riemann surfaces. -/
noncomputable abbrev mℂ := modelWithCornersSelf ℂ ℂ

/-- Bishop–Rempe defines a branched covering between surfaces as a map `f : X → S` such that
every point of `S` has a simply connected neighborhood U such that each connected component V
of f⁻¹(U) is simply connected and `f : V → U` is a proper map topological equivalent to z ↦ zᵈ
for some `d ≥ 1`. We omit the last condition since it is automatic for a holomorphic map between
Riemann surfaces if U is sufficiently small. Definition 3.4.4 in
https://people.cs.dm.unipi.it/bianchi/teaching/2017_M3PA50/M3PA50_chp3.pdf
requires only connectedness rather than simple connectedness. -/
def IsBranchedCovering {X S : Type*} [TopologicalSpace X] [TopologicalSpace S] (f : X → S) :
    Prop :=
  ∀ w : S, ∃ U ∈ nhds w, IsSimplyConnected U ∧ ∀ x ∈ f⁻¹' U,
    IsSimplyConnected (connectedComponentIn (f ⁻¹' U) x) ∧
    IsProperMap (Set.restrictPreimage U f ∘ Set.inclusion (connectedComponentIn_subset (f ⁻¹' U) x))

/-- Every non-compact Riemann surface admits a holomorphic branched covering map to the Riemann
sphere branched only over three points. The Riemann sphere does not exist in Mathlib yet, so we
instead talk about an arbitrary Riemann surface structure on the 2-sphere.
It is assumed that the Riemann surface is second countable to avoid invoking Radó's theorem. -/
@[eval_problem]
theorem bishop_rempe {X : Type*} [TopologicalSpace X] [T2Space X] [ConnectedSpace X]
    [SecondCountableTopology X] [ChartedSpace ℂ X] [IsManifold mℂ 1 X] (h : ¬ CompactSpace X) :
    let S := Metric.sphere (0 : EuclideanSpace ℝ (Fin 3)) 1
    ∃ (_ : ChartedSpace ℂ S) (_ : IsManifold mℂ 1 S) (f : X → S) (s : Set S),
      ContMDiff mℂ mℂ 1 f ∧ IsBranchedCovering f ∧ IsCoveringMapOn f sᶜ ∧ s.ncard = 3 := by
  sorry

end LeanEval.Geometry.EquilateralTriangulation
