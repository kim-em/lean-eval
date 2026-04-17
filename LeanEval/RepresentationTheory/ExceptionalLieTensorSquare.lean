import Mathlib.Algebra.Lie.SerreConstruction
import Mathlib.Algebra.Lie.TensorProduct
import Mathlib.Algebra.Lie.UniversalEnveloping
import Mathlib.Algebra.Lie.Semisimple.Defs
import Mathlib.Data.Complex.Basic
import Mathlib.LinearAlgebra.Dimension.Finrank
import Mathlib.RingTheory.SimpleModule.Isotypic
import EvalTools.Markers

namespace LeanEval
namespace RepresentationTheory

open scoped TensorProduct

/-!
Tensor square decomposition for irreducible representations of g₂ and e₈
defined by the Serre construction.

For each of the exceptional Lie algebras g₂ and e₈ over ℂ, the irreducible
representation with highest weight `ω₁ + ω_n` (the sum of the first and last
fundamental weights, in Bourbaki labelling) has a particular dimension `d`,
and its tensor square decomposes into `k` isotypic components (counted as
distinct isomorphism classes of irreducible Lie submodules):

* g₂: dim V = 64,     k = 14   (highest weight ω₁ + ω₂)
* e₈: dim V = 779247, k = 40   (highest weight ω₁ + ω₈)

Mathlib's `isotypicComponents` is defined for modules over a ring. To use it
on a Lie module `M`, we transport the action through the universal enveloping
algebra: a `LieModule R L M` extends to a `Module (UniversalEnvelopingAlgebra R L) M`
via the universal property.
-/

noncomputable instance lieModuleToEnvelopingModule
    (R L M : Type*) [CommRing R] [LieRing L] [LieAlgebra R L]
    [AddCommGroup M] [Module R M] [LieRingModule L M] [LieModule R L M] :
    Module (UniversalEnvelopingAlgebra R L) M :=
  Module.compHom M
    (UniversalEnvelopingAlgebra.lift R (LieModule.toEnd R L M)).toRingHom

@[eval_problem]
theorem g2_irrep_tensor_square_decomp :
    ∃ (V : Type) (_ : AddCommGroup V) (_ : Module ℂ V)
      (_ : LieRingModule (LieAlgebra.g₂ ℂ) V) (_ : LieModule ℂ (LieAlgebra.g₂ ℂ) V),
      Module.finrank ℂ V = 64 ∧
      LieModule.IsIrreducible ℂ (LieAlgebra.g₂ ℂ) V ∧
      (isotypicComponents (UniversalEnvelopingAlgebra ℂ (LieAlgebra.g₂ ℂ))
        (V ⊗[ℂ] V)).ncard = 14 := by
  sorry

@[eval_problem]
theorem e8_irrep_tensor_square_decomp :
    ∃ (V : Type) (_ : AddCommGroup V) (_ : Module ℂ V)
      (_ : LieRingModule (LieAlgebra.e₈ ℂ) V) (_ : LieModule ℂ (LieAlgebra.e₈ ℂ) V),
      Module.finrank ℂ V = 779247 ∧
      LieModule.IsIrreducible ℂ (LieAlgebra.e₈ ℂ) V ∧
      (isotypicComponents (UniversalEnvelopingAlgebra ℂ (LieAlgebra.e₈ ℂ))
        (V ⊗[ℂ] V)).ncard = 40 := by
  sorry

end RepresentationTheory
end LeanEval
