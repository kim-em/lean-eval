import Mathlib

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



end RepresentationTheory
end LeanEval
