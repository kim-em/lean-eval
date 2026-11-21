import Mathlib

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




instance Place.instIsScalarTower : IsScalarTower K v F := inferInstanceAs (IsScalarTower K v.toSubalgebra F)

instance Place.instValuationRing : ValuationRing v := inferInstanceAs (ValuationRing v.toValuationSubring)

variable {F}



variable (F)

open scoped RestrictedProduct

/-- [Stichtenoth, Definition 1.5.2]. -/
abbrev Adele : Type _ := RestrictedProduct (fun _ ↦ F) (fun v : Place K F ↦ v) Filter.cofinite

instance Adele.instCommRing : CommRing (Adele K F) := RestrictedProduct.instCommRingCoeOfSubringClass ..

open RestrictedProduct

variable {F}



variable (F)



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



/-- The $K$-subspace $\mathcal{A}_F(0)$, see [Stichtenoth, Definition 1.5.3]. -/
def integralAdele : Submodule K (Adele K F) where
  carrier := {x | ∀ v, x v ∈ v}
  add_mem' h₁ h₂ v := add_mem (h₁ v) (h₂ v)
  zero_mem' _ := zero_mem _
  smul_mem' _ _ h v := v.smul_mem (h v) _





end LeanEval.AlgebraicGeometry.Faltings
