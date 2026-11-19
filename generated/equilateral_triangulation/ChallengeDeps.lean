import Mathlib

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



end LeanEval.Geometry.EquilateralTriangulation
