import Mathlib.FieldTheory.KrullTopology
import Mathlib.NumberTheory.NumberField.Basic
import EvalTools.Markers

/-!
# The Neukirch–Uchida theorem

Every topological group isomorphism between absolute Galois groups of two number fields is induced
by a unique isomorphism between their separable closures that sends one field to the other.
A foundational result of anabelian geometry.

References:
https://en.wikipedia.org/wiki/Neukirch%E2%80%93Uchida_theorem
Jürgen Neukirch, Alexander Schmidt, Kay Wingberg. *Cohomology of Number Fields*, Theorem 12.2.1.
-/

namespace LeanEval.NumberTheory

@[eval_problem]
theorem neukirch_uchida {K₁ K₂ K₁' K₂' : Type*} [Field K₁] [Field K₂] [Field K₁'] [Field K₂']
    [NumberField K₁] [NumberField K₂] [Algebra K₁ K₁'] [Algebra K₂ K₂'] [IsSepClosure K₁ K₁']
    [IsSepClosure K₂ K₂'] (ϕ : Gal(K₁'/K₁) ≃* Gal(K₂'/K₂)) (he : IsHomeomorph ϕ) :
    ∃! σ : K₂' ≃+* K₁', (algebraMap K₂ K₂').range.map σ.toRingHom = (algebraMap K₁ K₁').range ∧
      ∀ g : Gal(K₁'/K₁), ϕ g = σ.trans (g.toRingEquiv.trans σ.symm) := by
  sorry

end LeanEval.NumberTheory
