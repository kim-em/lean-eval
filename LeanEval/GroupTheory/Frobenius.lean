import Mathlib
import EvalTools.Markers

namespace LeanEval
namespace GroupTheory

/-!
Frobenius's theorem on Frobenius groups.

A *Frobenius group* is a finite group `G` acting transitively and faithfully on
a set `X` (with `|X| ≥ 2`) such that:
* point stabilisers are non-trivial, and
* no non-identity element of `G` fixes more than one point of `X`.

Frobenius's theorem (1901) states that the *Frobenius kernel*
  `K = {1} ∪ {g ∈ G | g fixes no point of X}`
is a normal subgroup of `G`. The only known proof uses character theory
(induction of characters from a point stabiliser to `G`); no purely
group-theoretic proof has been found in over a century.
-/

@[eval_problem]
theorem frobenius_kernel_isNormal
    (G X : Type) [Group G] [Fintype G] [Fintype X]
    [MulAction G X] [FaithfulSMul G X]
    (hcard : 2 ≤ Fintype.card X)
    (htrans : ∀ x y : X, ∃ g : G, g • x = y)
    (hstab : ∀ x : X, MulAction.stabilizer G x ≠ ⊥)
    (hfrob : ∀ g : G, g ≠ 1 → ∀ x y : X, g • x = x → g • y = y → x = y) :
    ∃ N : Subgroup G, N.Normal ∧
      (N : Set G) = {1} ∪ {g : G | ∀ x : X, g • x ≠ x} := by
  sorry

end GroupTheory
end LeanEval
