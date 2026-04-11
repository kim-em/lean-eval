import ChallengeDeps
import Submission.Helpers

open scoped BigOperators

namespace Submission

theorem dvd_card_connectedComponent_markoffGraph {p : ℕ} (hp : Nat.Prime p) (hgt : 3 < p) :
    ∀ c : (markoffGraph p).ConnectedComponent, p ∣ Nat.card c := by
  sorry

end Submission
