import Mathlib
import ChallengeDeps
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



end ValuationSubalgebra

variable (K F : Type*) [Field K] [Field F] [Algebra K F]











variable (v : Place K F)

instance Place.instHasMemOrInvMem : HasMemOrInvMem v where
  mem_or_inv_mem := v.mem_or_inv_mem'

instance Place.instAlgebra : Algebra v F := inferInstanceAs (Algebra v.toSubalgebra F)

instance Place.instIsFractionRing : IsFractionRing v F := inferInstanceAs (IsFractionRing v.toValuationSubring F)


variable {F}

/-- [Stichtenoth, Corollary 1.3.4] (finitely many poles). -/
theorem finite_setOf_place_notMem [BundledFunctionField K F] (x : F) :
    {v : Place K F | x ∉ v}.Finite := by
  sorry

variable (F)

open scoped RestrictedProduct





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


instance Adele.instIsScalarTower [BundledFunctionField K F] : IsScalarTower K F (Adele K F) :=
  .of_algebraMap_eq fun _ ↦ rfl



/-- The genus of a function field, [Stichtenoth, Corollary 1.5.5]. -/
noncomputable def genus [BundledFunctionField K F] : ℕ := Module.finrank K
  (Adele K F ⧸ integralAdele K F ⊔ (IsScalarTower.toAlgHom K F _).toLinearMap.range)

/-- Every function field of genus at least 2 (equivalently, every curve of geometric genus
at least 2) over a number field has only finitely many rational points.
Note: if K is not the full constant field of F/K then there are no rational points, because
every place contains the full constant field. -/
theorem faltings [NumberField K] [BundledFunctionField K F] (h : 2 ≤ genus K F) :
    {v : Place K F | Module.rank K (IsLocalRing.ResidueField v) = 1}.Finite := by
  sorry

end LeanEval.AlgebraicGeometry.Faltings
