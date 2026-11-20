import Mathlib.AlgebraicGeometry.Birational.Birational
import Mathlib.AlgebraicGeometry.Birational.Composition
import Mathlib.AlgebraicGeometry.Morphisms.Proper
import Mathlib.Basic.Complex.Basic
import Mathlib.NumberTheory.NumberField.Basic

/-!
# Main Statement from Motivic invariants of birational maps

We formalise the statement of the main result from H.-Y. Lin and E. Shinder,
`Motivic invariants of birational maps`, Annals of Math, 199 (1) 2024.
-/

set_option autoImplicit false

universe u

noncomputable section

section Mathlib

namespace AlgebraicGeometry.Scheme

open CategoryTheory

/-- A birational map between irreducible schemes `X` and `Y`. Consists of a pair of dominant
mutually inverse rational maps `hom : X ⤏ Y` and `inv : Y ⤏ X`. -/
structure BirationalMap (X Y : Scheme.{u}) [IrreducibleSpace X] [IrreducibleSpace Y] where
  /-- The forward rational map of a birational map. -/
  hom : X ⤏ Y
  [isDominant_hom : hom.IsDominant]
  /-- The inverse rational map of a birational map. -/
  inv : Y ⤏ X
  [isDominant_inv : inv.IsDominant]
  hom_comp_inv_id : hom.comp inv = .id X := by grind
  inv_comp_hom_id : inv.comp hom = .id Y := by grind

attribute [instance] BirationalMap.isDominant_hom BirationalMap.isDominant_inv

attribute [simp, grind =] BirationalMap.hom_comp_inv_id BirationalMap.inv_comp_hom_id

namespace BirationalMap

variable {X Y Z : Scheme.{u}} [IrreducibleSpace X] [IrreducibleSpace Y] [IrreducibleSpace Z]

@[ext]
lemma ext (f g : X.BirationalMap Y) (e : f.hom = g.hom) : f = g := by
  suffices f.inv = g.inv by grind [BirationalMap]
  calc
    f.inv = f.inv.comp (g.hom.comp g.inv) := by grind
    _     = g.inv := by grind

variable (X) in
/-- The identity birational map on `X`. -/
@[simps]
def refl : X.BirationalMap X where
  hom := RationalMap.id X
  inv := RationalMap.id X

/-- The inverse of a birational map. -/
@[simps]
def symm (f : X.BirationalMap Y) : Y.BirationalMap X where
  hom := f.inv
  inv := f.hom

/-- The composition of two birational maps. -/
@[simps]
noncomputable def trans (f : X.BirationalMap Y) (g : Y.BirationalMap Z) :
    BirationalMap X Z where
  hom := f.hom.comp g.hom
  inv := g.inv.comp f.inv

theorem refl_trans (f : X.BirationalMap Y) : (refl X).trans f = f := by
  ext; simp

theorem trans_refl (f : X.BirationalMap Y) : f.trans (refl Y) = f := by
  ext; simp

theorem symm_trans_self_id (f : X.BirationalMap Y) : f.symm.trans f = refl Y := by
  ext; simp

theorem trans_assoc {W : Scheme.{u}} [IrreducibleSpace W]
    (f : X.BirationalMap Y) (g : Y.BirationalMap Z) (h : Z.BirationalMap W) :
    (f.trans g).trans h = f.trans (g.trans h) := by
  ext; simp only [BirationalMap.trans_hom, f.hom.comp_assoc]

noncomputable instance : Group (X.BirationalMap X) where
  one := refl X
  inv := symm
  mul := trans
  mul_assoc := trans_assoc
  one_mul := refl_trans
  mul_one := trans_refl
  inv_mul_cancel := symm_trans_self_id

/-- A birational map between irreducible schemes `X` and `Y` over a base scheme `S`: a
`BirationalMap` whose underlying forward rational map is an `S`-map.
The inverse is then automatically an `S`-map too; see `inv_compHom` below. -/
class IsOver (S : Scheme.{u}) [X.Over S] [Y.Over S] (f : X.BirationalMap Y) : Prop where
  /-- The forward rational map commutes with the structure maps to the base. -/
  over : f.hom.compHom (Y ↘ S) = (X ↘ S).toRationalMap

lemma inv_compHom (S : Scheme.{u}) [X.Over S] [Y.Over S]
    (f : BirationalMap X Y) (hf : f.IsOver S) :
    f.inv.compHom (X ↘ S) = (Y ↘ S).toRationalMap := by
  rw [← RationalMap.comp_toRationalMap, ← hf.over, ← RationalMap.comp_toRationalMap,
    ← RationalMap.comp_assoc]
  simp only [f.inv_comp_hom_id, RationalMap.id_comp]

end BirationalMap

variable {X Y : Scheme.{u}}

lemma PartialMap.id_domain : (PartialMap.id X).domain = ⊤ := rfl

lemma PartialMap.id_hom : (PartialMap.id X).hom = X.topIso.hom := by
  rw [Hom.toPartialMap_hom, Category.comp_id]

set_option backward.defeqAttrib.useBackward true in
instance isDominant_toPartialMap_hom (f : X.PartialIso Y) : IsDominant f.toPartialMap.hom := by
  dsimp only [PartialIso.toPartialMap_domain, PartialIso.toPartialMap_hom]
  have := Opens.isDominant_ι f.dense_target
  infer_instance

@[simp]
lemma Opens.morphismRestrict_ι {X : Scheme.{u}} (U : X.Opens) :
    U.ι ∣_ U = Scheme.homOfLE _ U.ι_preimage_self.le ≫ (⊤ : Opens U).ι := by
  simp [← cancel_mono U.ι]

set_option backward.isDefEq.respectTransparency.types false in
lemma PartialIso.toPartialMap_comp_symm [PreirreducibleSpace X] [Nonempty Y] (f : X.PartialIso Y) :
    f.toPartialMap.comp f.symm.toPartialMap =
      (PartialMap.id X).restrict f.source f.dense_source le_top := by
  ext1
  · change f.source.ι ''ᵁ f.iso.hom ⁻¹ᵁ f.target.ι ⁻¹ᵁ f.target = f.source
    rw [Opens.ι_preimage_self, Hom.preimage_top, Opens.ι_image_top]
  · change (f.source.ι.isoImage (f.iso.hom ⁻¹ᵁ f.target.ι ⁻¹ᵁ f.target)).inv ≫
      (f.iso.hom ≫ f.target.ι) ∣_ f.target ≫ f.iso.inv ≫ f.source.ι = _
    simp_rw [morphismRestrict_comp, Opens.morphismRestrict_ι, homOfLE_ι,
      morphismRestrict_ι, Category.assoc, Iso.hom_inv_id_assoc, Hom.isoImage_inv_ι, isoOfEq_hom,
      PartialMap.restrict_hom, PartialMap.id_domain, PartialMap.id_hom, topIso_hom, homOfLE_ι]
    exact (X.homOfLE_ι _).symm

set_option backward.isDefEq.respectTransparency.types false in
lemma PartialIso.symm_toPartialMap_comp [Nonempty X] [PreirreducibleSpace Y] (f : X.PartialIso Y) :
    f.symm.toPartialMap.comp f.toPartialMap =
      (PartialMap.id Y).restrict f.target f.dense_target le_top := by
  ext1
  · change f.target.ι ''ᵁ f.iso.inv ⁻¹ᵁ f.source.ι ⁻¹ᵁ f.source = f.target
    rw [Opens.ι_preimage_self, Hom.preimage_top, Opens.ι_image_top]
  · change (f.target.ι.isoImage (f.iso.inv ⁻¹ᵁ f.source.ι ⁻¹ᵁ f.source)).inv ≫
      (f.iso.inv ≫ f.source.ι) ∣_ f.source ≫ f.iso.hom ≫ f.target.ι = _
    simp_rw [morphismRestrict_comp, Opens.morphismRestrict_ι, homOfLE_ι,
      morphismRestrict_ι, Category.assoc, Iso.inv_hom_id_assoc, Hom.isoImage_inv_ι, isoOfEq_hom,
      PartialMap.restrict_hom, PartialMap.id_domain, PartialMap.id_hom, topIso_hom, homOfLE_ι]
    exact (Y.homOfLE_ι _).symm

variable [IrreducibleSpace X] [IrreducibleSpace Y]

variable (X) in
/-- The subgroup of the group of birational self-maps of `X` consisting of those maps
that are defined over the base scheme `S`. -/
def birationalAutOver (S : Scheme.{u}) [X.Over S] : Subgroup (X.BirationalMap X) where
  carrier := { f | f.IsOver S }
  one_mem' := ⟨by exact RationalMap.id_compHom _⟩
  mul_mem' {f g} hf hg := ⟨by
    change (f.hom.comp g.hom).compHom (X ↘ S) = (X ↘ S).toRationalMap
    rw [← RationalMap.comp_toRationalMap, RationalMap.comp_assoc,
      RationalMap.comp_toRationalMap, hg.over, RationalMap.comp_toRationalMap, hf.over]⟩
  inv_mem' {f} hf := ⟨f.inv_compHom S hf⟩



/-- A partial isomorphism gives rise to a birational map. -/
@[simps]
def PartialIso.toBirationalMap (f : X.PartialIso Y) : X.BirationalMap Y where
  hom := f.toRationalMap
  inv := f.symm.toRationalMap
  hom_comp_inv_id := by
    rw [RationalMap.toRationalMap_comp, PartialMap.toRationalMap_eq_iff,
      PartialIso.toPartialMap_comp_symm]
    apply PartialMap.restrict_equiv
  inv_comp_hom_id := by
    rw [RationalMap.toRationalMap_comp, PartialMap.toRationalMap_eq_iff,
      PartialIso.symm_toPartialMap_comp]
    apply PartialMap.restrict_equiv

end AlgebraicGeometry.Scheme

end Mathlib

namespace MotivicInvariants

open CategoryTheory AlgebraicGeometry Scheme

variable (𝕜 𝔽 : Type) [Field 𝕜] [Field 𝔽]

/-- By a variety over `𝕜`, we mean an irreducible and reduced separated scheme of
finite type over `𝕜`. Note that we say `IsIntegral` here instead of `IrreducibleSpace`
and `IsReduced`. Note also that in Mathlib, we don't have a bundled `FiniteType` class,
but instead say locally of finite type + quasicompact. -/
class Variety (X : Scheme) where
  [over : X.Over (Spec (.of 𝕜))]
  [isIntegral : IsIntegral X]
  [isSeparated : IsSeparated (X ↘ Spec (.of 𝕜))]
  [locallyOfFiniteType: LocallyOfFiniteType (X ↘ Spec (.of 𝕜))]
  [quasicompact : QuasiCompact (X ↘ Spec (.of 𝕜))]

attribute [instance_reducible] Variety.over

attribute [instance] Variety.over Variety.isIntegral

instance (n : ℕ) : Variety 𝕜 𝔸(Fin n; Spec (.of 𝕜)) where

/-- A partial isomorphism is a pseudo-isomorphism, if it is an isomorphism in codimension one. -/
structure _root_.AlgebraicGeometry.Scheme.PartialIso.IsPseudoIso
    {X Y : Scheme.{u}} (i : PartialIso X Y) : Prop where
  codim_source : ∀ x ∉ i.source, 2 ≤ Order.coheight x
  codim_target : ∀ y ∉ i.target, 2 ≤ Order.coheight y

/-- Auxiliary structure for `BirationalMap.IsPseudoRegularizable`. -/
structure PseudoRegularization {X : Scheme} [Variety 𝕜 X] (φ : BirationalMap X X) where
  /-- An irreducible scheme birational to `X`. -/
  X' : Scheme
  /-- The scheme is a variety. -/
  [variety : Variety 𝕜 X']
  /-- The birational map `α : X ⤏ X'`. -/
  α : BirationalMap X X'
  [isOver_α : α.IsOver (Spec (.of 𝕜))]
  /-- The pseudo-automorphism of `X'`, namely an isomorphism in codimension one. -/
  γ : PartialIso X' X'
  [isOver_γ : γ.IsOver (X' ↘ (Spec (.of 𝕜))) (X' ↘ (Spec (.of 𝕜)))]
  isPseudoIso : γ.IsPseudoIso
  cond : φ = (α.trans γ.toBirationalMap).trans α.symm

/-- Definition 4.1: A birational automorphism `φ` is pseudo-regularizable if
`φ = α⁻¹ ∘ γ ∘ α`, where
- `α : X ⤏ X'` is a birational map (we do not assume `X'` is smooth nor projective);
- `γ : X' ⤏ X'` is a pseudo-automorphism, namely an isomorphism in codimension one. -/
abbrev _root_.AlgebraicGeometry.Scheme.BirationalMap.IsPseudoRegularizable
    {X : Scheme} [Variety 𝕜 X] (φ : BirationalMap X X) : Prop :=
  Nonempty (PseudoRegularization 𝕜 φ)

/-- The Cremona group `Crₙ(𝕜)` over a field `𝕜`, defined as the group of birational
automorphisms of affine `n`-space over `𝕜`. -/
abbrev Cr (n : ℕ) : Type := 𝔸(Fin n; Spec (.of 𝕜)).birationalAutOver (Spec (.of 𝕜))

/-- The statement that `Crₙ(𝕜)` is generated by pseudo-regularizable elements. -/
abbrev GenByPseudoRegularizable (n : ℕ) : Prop :=
  Subgroup.closure { f : Cr 𝕜 n | f.1.IsPseudoRegularizable 𝕜 } = ⊤













end MotivicInvariants
