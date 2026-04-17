import ChallengeDeps
import Submission.Helpers

open LeanEval.RepresentationTheory
open scoped TensorProduct

namespace Submission

theorem glAction_range_eq_centralizer_symAction {R : Type*} [Field R]
    {M : Type*} [AddCommGroup M] [Module R M] [FiniteDimensional R M]
    {k : ℕ} [Invertible (k.factorial : R)] :
    Algebra.adjoin R (Set.range (glAction R M k)) =
      Subalgebra.centralizer R (Set.range (symAction R M k)) := by
  sorry

end Submission
