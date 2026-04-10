import ChallengeDeps

open FormalMathEval.Combinatorics

open scoped BigOperators

theorem dvd_card_connectedComponent_markoffGraph {p : ℕ} (hp : Nat.Prime p) (hgt : 3 < p) :
    ∀ c : (markoffGraph p).ConnectedComponent, p ∣ Nat.card c := by
  sorry
