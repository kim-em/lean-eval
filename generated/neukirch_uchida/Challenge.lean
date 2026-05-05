import Mathlib

theorem neukirch_uchida {K₁ K₂ K₁' K₂' : Type*} [Field K₁] [Field K₂] [Field K₁'] [Field K₂']
    [NumberField K₁] [NumberField K₂] [Algebra K₁ K₁'] [Algebra K₂ K₂'] [IsSepClosure K₁ K₁']
    [IsSepClosure K₂ K₂'] (ϕ : Gal(K₁'/K₁) ≃* Gal(K₂'/K₂)) (he : IsHomeomorph ϕ) :
    ∃! σ : K₂' ≃+* K₁', (algebraMap K₂ K₂').range.map σ.toRingHom = (algebraMap K₁ K₁').range ∧
      ∀ g : Gal(K₁'/K₁), ϕ g = σ.trans (g.toRingEquiv.trans σ.symm) := by
  sorry
