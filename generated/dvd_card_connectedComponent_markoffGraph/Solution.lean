import ChallengeDeps
import Submission

open LeanEval.Combinatorics
open scoped BigOperators

theorem dvd_card_connectedComponent_markoffGraph {p : ℕ} (hp : Nat.Prime p) (hgt : 3 < p) :
    ∀ c : (markoffGraph p).ConnectedComponent, p ∣ Nat.card c := by
  exact Submission.dvd_card_connectedComponent_markoffGraph hp hgt
