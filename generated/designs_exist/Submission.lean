import Mathlib
import Submission.Helpers
import ChallengeDeps
/-!
# Existence of designs

Peter Keevash showed in 2014 that designs of parameters (n, q, r, λ) exist provided
n is sufficiently large (given fixed q, r, λ).

We include multiple related results with similar methods of proof in this challenge
to encourage production of reusable code.

## References

* Peter Keevash. The existence of designs. https://arxiv.org/abs/1401.3665
* Peter Keevash. The existence of designs II. https://people.maths.ox.ac.uk/keevash/papers/designsII.pdf
* Peter Keevash. Counting designs. https://arxiv.org/abs/1504.02909
* Peter Keevash, Ashwin Sah, Mehtaab Sawhney. The existence of subspace designs. https://arxiv.org/abs/2212.00870
* Stefan Glock, Daniela Kühn, Allan Lo, Deryk Osthus. The existence of designs via iterative absorption: hypergraph F-designs for arbitrary F. https://arxiv.org/abs/1611.06827
* W. T. Gowers. Probabilistic combinatorics and the recent work of Peter Keevash. https://www.ams.org/journals/bull/2017-54-01/S0273-0979-2016-01553-9/S0273-0979-2016-01553-9.pdf
* Gil Kalai. Designs Exist! [after Peter Keevash] http://www.bourbaki.ens.fr/TEXTES/1100.pdf
* https://aperiodical.com/2014/01/proof-news-designs-exist/ includes links to multiple blog posts.
-/

namespace Submission

open _root_.LeanEval
open _root_.LeanEval.Combinatorics
open _root_.LeanEval.Combinatorics.DesignsExist
open _root_.LeanEval.Combinatorics.DesignsExist.Design
open _root_.LeanEval.Combinatorics.DesignsExist.SubspaceDesign
namespace LeanEval.Combinatorics.DesignsExist





/-- Existence of designs. Theorem 0.1 in Kalai's Bourbaki notes. -/
theorem keevash (q r lam : ℕ+) (hrq : r < q) :
    ∃ N : ℕ, ∀ n > N, DivisibilityCondition n q r lam → Nonempty (Design (Fin n) q r lam) := by
  sorry

/-- Asymptotics on the number of Steiner triple systems: if n is 1 or 3 mod 6, then
the number of Steiner triple systems on n vertices is (n/e² + o(n)) ^ (n²/6).
Theorem 2.2 of *Counting designs*. -/
theorem steiner_triple_asymptotics :
    (fun n : ℕ ↦ Nat.card (Design (Fin n) 3 2 1) ^ (6 / n ^ 2 : ℝ) -
      if 6 ∣ (n + 5) ∨ 6 ∣ (n + 3) then n / Real.exp 2 else 0) =o[Filter.atTop] ((↑) : ℕ → ℝ) := by
  sorry

/-- Existence of resolvable designs (for which the set of blocks can be partitioned into partitions.
Theorem 1.1 in *The existence of designs II*. -/
theorem keevash_resolvable (q r lam : ℕ+) (hrq : r < q) :
    ∃ N : ℕ, ∀ n > N, DivisibilityCondition n q r lam → (q : ℕ) ∣ n →
      ∃ d : Design (Fin n) q r lam, ∃ p : Partition d.blocks,
        ∀ s ∈ p, ∃ p' : Partition (.univ : Set (Fin n)), p' = s := by
  sorry

/-- Existence of a large set of designs. Theorem 1.2 in *The existence of designs II*. -/
theorem keevash_large_set (q r : ℕ+) (hrq : r ≤ q) :
    ∃ N : ℕ, ∀ n > N, ∀ lam : ℕ+, DivisibilityCondition n q r lam →
      (lam : ℕ) ∣ (n - r : ℕ).choose (q - r) →
      ∃ p : Partition {s : Set (Fin n) | s.encard = q},
        ↑p ⊆ Set.range fun d : Design (Fin n) q r lam ↦ d.blocks := by
  sorry

/-- Existence of a complete resolution of Kₙ^q. The divisibility condition is
`n = q` modulo `lcm(1, ..., q)`, as in Theorem 1.3 of *The existence of designs II*. -/
theorem keevash_complete_resolution (q : ℕ+) :
    ∃ N : ℕ, ∀ n > N, (∀ i ∈ Finset.Icc 1 (q : ℕ), i ∣ (n - q)) →
      ∃ s : Π i : Fin q, Set (Design (Fin n) q (i + 1) 1),
        (s (.rev 0)).encard = 1 ∧ ∀ i j : Fin q, i ≤ j →
          ∀ d ∈ s j, ∃ p : Partition d.blocks, ↑p ⊆ Design.blocks '' s i := by
  sorry





/-- Existence of subspace designs: Theorem 1.4 in the paper by Keevash, Sah and Sawhney. -/
theorem keevash_sah_sawhney (K : Type*) [Finite K] [Field K] (s r : ℕ) (lt : r < s) (lam : ℕ+) :
    ∃ N, ∀ n > N, let q := Nat.card K
      (∀ i ∈ Finset.range r, qChoose q (s - i) (r - i) ∣ lam * qChoose q (n - i) (r - i)) →
      Nonempty (SubspaceDesign K (Fin n → K) s r lam) := by
  sorry

end LeanEval.Combinatorics.DesignsExist

end Submission
