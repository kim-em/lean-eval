import Mathlib
import EvalTools.Markers

/-!
# Faltings' theorem (Mordell conjecture)

This file defines basic objects associated to function fields of one variable following
[Stichtenoth] just enough to state Faltings' theorem.

The repository https://github.com/vaca22/riemann-roch-function-fields contains more
advanced development of the theory of function fields.

[Stichtenoth] Henning Stichtenoth, *Algebraic Function Fields and Codes*, Second Edition.
-/

namespace LeanEval.AlgebraicGeometry.Faltings

section ValuationSubalgebra

variable (R F : Type*) [CommSemiring R] [Field F] [Algebra R F]

@[ext] structure ValuationSubalgebra extends Subalgebra R F, ValuationSubring F

end ValuationSubalgebra

variable (K F : Type*) [Field K] [Field F] [Algebra K F]

class BundledFunctionField extends
  Algebra (RatFunc K) F, IsScalarTower K (RatFunc K) F, FunctionField K F

/-- The type of places of a 1-dimensional function field. See [Stichtenoth,
Definition 1.1.4 and 1.1.8]. We omit the condition `toSubalgebra ≠ ⊥` since it is automatic. -/
@[ext] structure Place extends ValuationSubalgebra K F where
  ne_top : toSubalgebra ≠ ⊤

instance Place.instSetLike : SetLike (Place K F) F where
  coe v := v.carrier
  coe_injective _ _ := Place.ext

instance Place.instSMulMemClass : SMulMemClass (Place K F) K F where
  smul_mem {v} r _ h := v.smul_mem h r

instance Place.instSubringClass : SubringClass (Place K F) F where
  mul_mem {v} := v.mul_mem
  one_mem {v} := v.one_mem
  add_mem {v} := v.add_mem
  zero_mem {v} := v.zero_mem
  neg_mem {v} := v.toValuationSubring.neg_mem _

variable (v : Place K F)

instance Place.instHasMemOrInvMem : HasMemOrInvMem v where
  mem_or_inv_mem := v.mem_or_inv_mem'

instance Place.instAlgebra : Algebra v F := inferInstanceAs (Algebra v.toSubalgebra F)
instance Place.instIsScalarTower : IsScalarTower K v F := inferInstanceAs (IsScalarTower K v.toSubalgebra F)
instance Place.instIsFractionRing : IsFractionRing v F := inferInstanceAs (IsFractionRing v.toValuationSubring F)
instance Place.instValuationRing : ValuationRing v := inferInstanceAs (ValuationRing v.toValuationSubring)

variable {F}

/-- [Stichtenoth, Corollary 1.3.4] (finitely many poles). -/
@[eval_problem]
theorem finite_setOf_place_notMem [BundledFunctionField K F] (x : F) :
    {v : Place K F | x ∉ v}.Finite := by
  sorry

variable (F)

open scoped RestrictedProduct

/-- [Stichtenoth, Definition 1.5.2]. -/
abbrev Adele : Type _ := RestrictedProduct (fun _ ↦ F) (fun v : Place K F ↦ v) Filter.cofinite

instance Adele.instCommRing : CommRing (Adele K F) := RestrictedProduct.instCommRingCoeOfSubringClass ..

open RestrictedProduct

variable {F}

/-- The principal adele associated to an element in the function field. -/
def Adele.principal [BundledFunctionField K F] : F →+* Adele K F where
  toFun x := ⟨fun _ ↦ x, finite_setOf_place_notMem K x⟩
  map_one' := rfl
  map_mul' _ _ := rfl
  map_zero' := rfl
  map_add' _ _ := rfl

variable (F)

instance Adele.instAlgebraFunctionField [BundledFunctionField K F] : Algebra F (Adele K F) where
  smul x a := ⟨x • a, (Adele.principal K x * a).2⟩
  algebraMap := Adele.principal K
  commutes' _ _ := mul_comm ..
  smul_def' _ _ := rfl

-- TODO: generalize this to RestrictedProduct
instance Adele.instAlgebraConstants : Algebra K (Adele K F) where
  __ := RestrictedProduct.instModuleCoeOfSMulMemClass ..
  algebraMap.toFun x := ⟨fun _ ↦ algebraMap K F x, .of_forall fun _ ↦ algebraMap_mem ..⟩
  algebraMap.map_one' := by ext; exact (algebraMap K F).map_one
  algebraMap.map_mul' _ _ := by ext; exact (algebraMap K F).map_mul ..
  algebraMap.map_add' _ _ := by ext; exact (algebraMap K F).map_add ..
  algebraMap.map_zero' := by ext; exact (algebraMap K F).map_zero
  commutes' _ _ := mul_comm ..
  smul_def' _ _ := by ext; apply Algebra.smul_def

instance Adele.instIsScalarTower [BundledFunctionField K F] : IsScalarTower K F (Adele K F) :=
  .of_algebraMap_eq fun _ ↦ rfl

/-- The $K$-subspace $\mathcal{A}_F(0)$, see [Stichtenoth, Definition 1.5.3]. -/
def integralAdele : Submodule K (Adele K F) where
  carrier := {x | ∀ v, x v ∈ v}
  add_mem' h₁ h₂ v := add_mem (h₁ v) (h₂ v)
  zero_mem' _ := zero_mem _
  smul_mem' _ _ h v := v.smul_mem (h v) _

/-- The genus of a function field, [Stichtenoth, Corollary 1.5.5]. -/
noncomputable def genus [BundledFunctionField K F] : ℕ := Module.finrank K
  (Adele K F ⧸ integralAdele K F ⊔ (IsScalarTower.toAlgHom K F _).toLinearMap.range)

/-- Every function field of genus at least 2 (equivalently, every curve of geometric genus
at least 2) over a number field has only finitely many rational points.
Note: if K is not the full constant field of F/K then there are no rational points, because
every place contains the full constant field. -/
@[eval_problem]
theorem faltings [NumberField K] [BundledFunctionField K F] (h : 2 ≤ genus K F) :
    {v : Place K F | Module.rank K (IsLocalRing.ResidueField v) = 1}.Finite := by
  sorry

end LeanEval.AlgebraicGeometry.Faltings
