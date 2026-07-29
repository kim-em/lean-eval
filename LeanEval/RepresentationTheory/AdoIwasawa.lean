import Mathlib
import EvalTools.Markers

namespace LeanEval.RepresentationTheory.AdoIwasawa

/-!
# Ado's theorem and the Ado–Iwasawa theorem

These problems ask for a faithful finite-dimensional representation of a
finite-dimensional Lie algebra. The first assumes that the base field has
characteristic zero; the second makes no assumption on its characteristic.
-/

universe u

/-- Endomorphisms carry the commutator Lie bracket used in the representation
targets below. This named instance is also exported to generated workspaces. -/
instance moduleEndLieRing (K V : Type u) [Field K] [AddCommGroup V] [Module K V] :
    LieRing (Module.End K V) :=
  LieRing.ofAssociativeRing

variable {K L : Type u} [Field K] [LieRing L] [LieAlgebra K L]

/-- **Ado's theorem.** Every finite-dimensional Lie algebra over a field of
characteristic zero has a faithful finite-dimensional representation. -/
@[eval_problem]
theorem adoCharZero [CharZero K] [FiniteDimensional K L] :
    ∃ (V : Type u) (_ : AddCommGroup V) (_ : Module K V) (_ : FiniteDimensional K V)
      (ρ : L →ₗ⁅K⁆ Module.End K V), Function.Injective ρ := by
  sorry

/-- **The Ado–Iwasawa theorem.** Every finite-dimensional Lie algebra over an
arbitrary field has a faithful finite-dimensional representation. -/
@[eval_problem]
theorem adoIwasawa [FiniteDimensional K L] :
    ∃ (V : Type u) (_ : AddCommGroup V) (_ : Module K V) (_ : FiniteDimensional K V)
      (ρ : L →ₗ⁅K⁆ Module.End K V), Function.Injective ρ := by
  sorry

end LeanEval.RepresentationTheory.AdoIwasawa
