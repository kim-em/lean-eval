import ChallengeDeps
import Submission.Helpers

open LeanEval.AlgebraicGeometry.TopologicalReconstruction
open CategoryTheory AlgebraicGeometry

universe u

namespace Submission

theorem kollar_lieblich_olsson_sawin (X Y : Scheme.{u}) (K L : Type u)
    [Field K] [Field L] [CharZero K] [CharZero L] [IrreducibleSpace X] [IrreducibleSpace Y]
    (norm_X : IsNormalScheme X) (f : X ⟶ Spec (.of K)) (proj_f : IsProjectiveHom f)
    (norm_Y : IsNormalScheme Y) (g : Y ⟶ Spec (.of L)) (proj_g : IsProjectiveHom g)
    (h : 4 ≤ topologicalKrullDim X ∨
      (3 ≤ topologicalKrullDim X ∧ Algebra.EssFiniteType ℚ K ∧ Algebra.EssFiniteType ℚ L) ∨ 
      (2 ≤ topologicalKrullDim X ∧ Uncountable K ∧ Uncountable L))
    (homeo : X ≃ₜ Y) : ∃ iso : X ≅ Y, (iso.hom : X → Y) = homeo := by
  sorry

end Submission
