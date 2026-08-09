import Mathlib

/-!
# Topological reconstruction theorems for varieties

Let X and Y be normal, projective, irreducible schemes over fields of characteristic 0.
Assume that
* dim X ≥ 4, or
* dim X ≥ 3 and the fields are finitely generated field extensions of ℚ, or
* dim X ≥ 2 and the fields are uncountable.
Then every homeomorphism between X and Y extends to an isomorphism of schemes.
This theorem is the culmination of several reconstruction results proved in [KLOS20, Kol20].

The approach in [KLOS] naturally breaks into two parts:
* Reconstruction of a scheme from the underlying topological space together with the
  additional information of the linear equivalence relation on divisors.
* Reconstruction of linear equivalence from the topological space.

## Reference

* [KLOS] János Kollár, Max Lieblich, Martin Olsson, and Will Sawin.
  The Zariski topology, linear systems, and algebraic varieties.
  https://williamsawin.com/ReconstructionBook.pdf or 
  https://max.lieblich.us/wp-content/uploads/2021/09/reconstructionweb.pdf

* [KLOS20] János Kollár, Max Lieblich, Martin Olsson, and Will Sawin.
  Topological reconstruction theorems for varieties. https://arxiv.org/abs/2003.04847

* [Kol20] János Kollár. What determines a variety? https://arxiv.org/abs/2002.12424
-/

open CategoryTheory AlgebraicGeometry

namespace LeanEval.AlgebraicGeometry.TopologicalReconstruction

universe u

/-- The structure morphism from a projective space `ℙⁿ_R` to `Spec R`. -/
noncomputable def projToSpec {R A : Type u} [CommRing R] [CommRing A] [Algebra R A]
    (𝒜 : ℕ → Submodule R A) [GradedAlgebra 𝒜] : Proj 𝒜 ⟶ Spec (.of R) :=
  Proj.toSpecZero 𝒜 ≫ Spec.map (CommRingCat.ofHom (algebraMap ..))

/-- A morphism from a scheme to Spec R is projective if it factors through some
closed immersion into ℙⁿ_R. -/
def IsProjectiveHom {X : Scheme} {R : Type*} [CommRing R] (f : X ⟶ Spec (.of R)) : Prop :=
  let := @MvPolynomial.gradedAlgebra
  ∃ (n : ℕ) (i : X ⟶ Proj (MvPolynomial.homogeneousSubmodule (Fin n) R)),
    IsClosedImmersion i ∧ f = i ≫ projToSpec _

/-- A scheme X is normal if for all `x : X` the local ring O_{X,x} is a normal domain. -/
def IsNormalScheme (X : Scheme) : Prop :=
  ∀ x : X, IsDomain (X.presheaf.stalk x) ∧ IsIntegrallyClosed (X.presheaf.stalk x)



end LeanEval.AlgebraicGeometry.TopologicalReconstruction
