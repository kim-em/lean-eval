import ChallengeDeps
import Submission

open LeanEval.RepresentationTheory
open scoped TensorProduct

theorem e8_irrep_tensor_square_decomp :
    ∃ (V : Type) (_ : AddCommGroup V) (_ : Module ℂ V)
      (_ : LieRingModule (LieAlgebra.e₈ ℂ) V) (_ : LieModule ℂ (LieAlgebra.e₈ ℂ) V),
      Module.finrank ℂ V = 779247 ∧
      LieModule.IsIrreducible ℂ (LieAlgebra.e₈ ℂ) V ∧
      (isotypicComponents (UniversalEnvelopingAlgebra ℂ (LieAlgebra.e₈ ℂ))
        (V ⊗[ℂ] V)).ncard = 40 := by
  exact Submission.e8_irrep_tensor_square_decomp
