import Mathlib

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
namespace LeanEval.Combinatorics.DesignsExist

/-- The type of designs with parameter (#X, q, r, lam). -/
structure Design (X : Type*) (q r lam : ℕ) where
  blocks : Set (Set X)
  card_blocks : ∀ s ∈ blocks, s.encard = q
  card_subset : ∀ s : Set X, s.encard = r → {b ∈ blocks | s ⊆ b}.encard = lam

/-- The obvious necessary condition for a design of given parameters to exist. -/
def DivisibilityCondition (n q r lam : ℕ) : Prop :=
  ∀ i ∈ Finset.range r, (q - i).choose (r - i) ∣ lam * (n - i).choose (r - i)











/-- The type of subspace designs with parameter (dim V, s, r, lam). -/
structure SubspaceDesign (K V : Type*) [DivisionRing K] [AddCommGroup V] [Module K V]
    (s r lam : ℕ) where
  subspaces : Set (Subspace K V)
  rank_subspaces : ∀ W ∈ subspaces, Module.rank K W = s
  card_subset : ∀ U : Subspace K V, Module.rank K U = r → {W ∈ subspaces | U ≤ W}.encard = lam

/-- q-binomial coefficients. -/
def qChoose (q n k : ℕ) :=
  let prod (n : ℕ) := ∏ i ∈ Finset.Icc 1 n, (q ^ i - 1)
  prod n / (prod k * prod (n - k))



end LeanEval.Combinatorics.DesignsExist
