import ChallengeDeps
import Submission

open LeanEval.RepresentationTheory
open scoped TensorProduct

theorem g2_irrep_tensor_square_decomp :
    ∃ (V : Type) (_ : AddCommGroup V) (_ : Module ℂ V)
      (_ : LieRingModule (LieAlgebra.g₂ ℂ) V) (_ : LieModule ℂ (LieAlgebra.g₂ ℂ) V),
      Module.finrank ℂ V = 64 ∧
      LieModule.IsIrreducible ℂ (LieAlgebra.g₂ ℂ) V ∧
      (isotypicComponents (UniversalEnvelopingAlgebra ℂ (LieAlgebra.g₂ ℂ))
        (V ⊗[ℂ] V)).ncard = 14 := by
  exact Submission.g2_irrep_tensor_square_decomp
