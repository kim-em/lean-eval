import ChallengeDeps
import Submission.Helpers

open LeanEval.GroupTheory

namespace Submission

theorem schreier_conjecture (S : Type) [Group S] [Fintype S] [IsSimpleGroup S]
    (hS : ∃ a b : S, ¬ Commute a b) :
    IsSolvable (MulAut S ⧸ (MulAut.conj : S →* MulAut S).range) := by
  sorry

end Submission
