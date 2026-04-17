import ChallengeDeps
import Submission

open LeanEval.RepresentationTheory
open scoped TensorProduct

theorem symAction_range_eq_centralizer_glAction {R : Type*} [Field R]
    {M : Type*} [AddCommGroup M] [Module R M] [FiniteDimensional R M]
    {k : ℕ} [Invertible (k.factorial : R)] :
    Algebra.adjoin R (Set.range (symAction R M k)) =
      Subalgebra.centralizer R (Set.range (glAction R M k)) := by
  exact Submission.symAction_range_eq_centralizer_glAction
