import Mathlib

open scoped TensorProduct

theorem m23_irrep_tensor_square_decomp :
    ∃ (G : Type) (_ : Group G) (_ : Fintype G),
      Fintype.card G = 10200960 ∧
      ∃ (V : Type) (_ : AddCommGroup V) (_ : Module ℂ V)
        (_ : Module (MonoidAlgebra ℂ G) V)
        (_ : IsScalarTower ℂ (MonoidAlgebra ℂ G) V)
        (_ : Module (MonoidAlgebra ℂ G) (V ⊗[ℂ] V))
        (_ : IsScalarTower ℂ (MonoidAlgebra ℂ G) (V ⊗[ℂ] V)),
        Module.finrank ℂ V = 22 ∧
        IsSimpleModule (MonoidAlgebra ℂ G) V ∧
        (∀ (g : G) (v w : V),
          (MonoidAlgebra.of ℂ G g : MonoidAlgebra ℂ G) • (v ⊗ₜ[ℂ] w) =
            ((MonoidAlgebra.of ℂ G g : MonoidAlgebra ℂ G) • v) ⊗ₜ[ℂ]
              ((MonoidAlgebra.of ℂ G g : MonoidAlgebra ℂ G) • w)) ∧
        (isotypicComponents (MonoidAlgebra ℂ G) (V ⊗[ℂ] V)).ncard = 4 := by
  sorry
