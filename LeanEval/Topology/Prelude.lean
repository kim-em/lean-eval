import Mathlib.Algebra.Category.Grp.Basic
import Mathlib.Algebra.Category.Grp.Abelian
import Mathlib.AlgebraicTopology.SingularHomology.Basic
import Mathlib.Analysis.Complex.Circle
import Mathlib.Analysis.InnerProductSpace.PiL2
import EvalTools.Markers

/-!
# Basic definitions in topology

## Main definitions

+ `singularHomology`, `bettiNumber`: the singular homology and Betti numbers of a topological
space with coefficients in an abelian group.

+ `ContinuousMap.toEndSingularHomology`: the homomorphism from the monoid of continuous maps
from a space to itself to the endomorphism monoid of one of its singular homology groups.

+ `Surface.OrientableRepr`, `Surface.NonOrientableRepr`: a representative surface in each
homeomorphism class of surfaces, obtained by gluing certain arcs in the boundary of the unit disc.

+ `handlebody₃`: a representative 3-dimensional handlebody for each genus.
See https://en.wikipedia.org/wiki/Handlebody#3-dimensional_handlebodies.

We pose it as a LeanEval problem to show that the boundary of the handlebody is homeomorphic
to the corresponding representative surface.
-/

section Topology

variable (X : Type*) [TopologicalSpace X]

instance : Monoid C(X, X) where
  mul := .comp
  mul_assoc _ _ _ := rfl
  one := .id X
  one_mul _ := rfl
  mul_one _ := rfl

instance : Group (X ≃ₜ X) where
  mul f g := g.trans f
  mul_assoc _ _ _ := rfl
  one := .refl _
  one_mul _ := rfl
  mul_one _ := rfl
  inv := .symm
  inv_mul_cancel f := by ext; apply f.left_inv

def Homeomorph.toContinuousMap : (X ≃ₜ X) →* C(X, X) where
  toFun := (↑)
  map_one' := rfl
  map_mul' _ _ := rfl

end Topology

section AlgebraicTopology

open AlgebraicTopology CategoryTheory

universe u in
instance : Limits.HasCoproducts.{u} AddCommGrpCat.{u} := inferInstance

variable (n : ℕ) (X : Type*) [TopologicalSpace X] (G : Type) [AddCommGroup G]

noncomputable abbrev singularHomology :=
  ((singularHomologyFunctor AddCommGrpCat n).obj (.of (ULift G))).obj (.of X)

noncomputable def bettiNumber : ℕ := Module.finrank ℤ <| singularHomology n X ℤ

noncomputable def ContinuousMap.toEndSingularHomology :
    C(X, X) →* AddMonoid.End (singularHomology n X G) where
  toFun f := (((singularHomologyFunctor AddCommGrpCat n).obj _).map <| TopCat.ofHom f).hom
  map_one' := AddCommGrpCat.ofHom_injective <| by simp; exact CategoryTheory.Functor.map_id ..
  map_mul' _ _ := AddCommGrpCat.ofHom_injective <| by simp; exact Functor.map_comp ..

end AlgebraicTopology

namespace Complex

/-- The closed unit disc in the complex plane. -/
abbrev ClosedUnitDisc : Type := Metric.closedBall (0 : ℂ) 1

/-- The boundary point exp(2πir) on the boundary of the closed unit disc in the complex plane. -/
noncomputable def ClosedUnitDisc.bdyPtOfReal (r : ℝ) : ClosedUnitDisc :=
  ⟨r.fourierChar, r.fourierChar.2.le⟩

end Complex

namespace LeanEval.Topology

namespace Surface

open Complex Set

/-- The representative orientable surface homeomorphic to a closed orientable genus `p`
surface with `n` discs removed (if `p` and `n` are not both zero), obtained by identifying
the boundary of a disc in the pattern `a₁b₁a₁⁻¹b₁⁻¹⋯aₚbₚaₚ⁻¹bₚ⁻¹c₁h₁c₁⁻¹⋯cₙhₙcₙ⁻¹`. -/
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

abbrev OrientableRepr (p n : ℕ) := Quot (Surface.OrientableRel p n)

abbrev NonOrientableRepr (p n : ℕ) := Quot (Surface.NonOrientableRel p n)

end Surface

open Set

/-- A 3-dimensional handlebody of genus `g`. -/
def handlebody₃ (g : ℕ) : Set (ℝ × ℝ × ℝ) :=
  Icc 0 1 ×ˢ (Icc 0 (2 * (g : ℝ) + 1) ×ˢ Icc 0 3 \ ⋃ i : Fin g, Ioo (2 * (i : ℝ) + 1) (2 * i + 2) ×ˢ Ioo 1 2)

@[eval_problem]
def frontierHandlebodyHomeomorphOrientableRepr (g : ℕ) (hg : g ≠ 0) :
    frontier (handlebody₃ g) ≃ₜ Surface.OrientableRepr g 0 := by
  sorry

@[eval_problem]
def frontierHandlebodyHomeomorphSphere :
    frontier (handlebody₃ 0) ≃ₜ Metric.sphere (0 : EuclideanSpace ℝ (Fin 3)) 1 := by
  sorry

@[eval_problem]
def frontierHandlebodyHomeomorphAddCircleProd :
    frontier (handlebody₃ 1) ≃ₜ AddCircle (1 : ℝ) × AddCircle (1 : ℝ) := by
  sorry

end LeanEval.Topology
