import Mathlib.FieldTheory.KrullTopology
import Mathlib.NumberTheory.NumberField.Basic
import EvalTools.Markers

/-!
# The Neukirch–Uchida theorem

Every topological group isomorphism between absolute Galois groups of two number fields
is induced by an isomorphism between the fields. A foundational result of anabelian geometry.

References:
https://en.wikipedia.org/wiki/Neukirch%E2%80%93Uchida_theorem
Jürgen Neukirch, Alexander Schmidt, Kay Wingberg. *Cohomology of Number Fields*, Theorem 12.2.1.
-/

namespace LeanEval.NumberTheory

@[eval_problem]
theorem neukirch_uchida {K₁ K₂ K₁' K₂' : Type*} [Field K₁] [Field K₂] [Field K₁'] [Field K₂']
    [NumberField K₁] [NumberField K₂] [Algebra K₁ K₁'] [Algebra K₂ K₂'] [IsAlgClosure K₁ K₁']
    [IsAlgClosure K₂ K₂'] (ϕ : Gal(K₁'/K₁) ≃* Gal(K₂'/K₂)) (he : IsHomeomorph ϕ) :
    ∃! σ : K₁' ≃+* K₂', (algebraMap K₁ K₁').range.map σ.toRingHom = (algebraMap K₂ K₂').range ∧
      ∀ g : Gal(K₁'/K₁), g.toRingEquiv.trans σ = σ.trans (ϕ g) := by
  sorry

end LeanEval.NumberTheory
