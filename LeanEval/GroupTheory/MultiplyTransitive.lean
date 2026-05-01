import Mathlib
import EvalTools.Markers

namespace LeanEval
namespace GroupTheory

/-!
Classification of `5`-transitive finite permutation groups (uses CFSG).

If a finite group `G` acts faithfully and `5`-transitively on a set `X` of
cardinality `n ≥ 5`, then `|G|` is one of:

* `n!`             (`G ≅ Sₙ`,    any `n ≥ 5`)
* `n! / 2`         (`G ≅ Aₙ`,    any `n ≥ 7`)
* `95 040`         (`G ≅ M₁₂`,    `n = 12`)
* `244 823 040`    (`G ≅ M₂₄`,    `n = 24`)

These are the only `5`-transitive finite groups. The result is folklore via
the classification of finite simple groups: it follows from CFSG together with
classical work of Mathieu, Jordan, and others. No CFSG-free proof is known.

The `5 ≤ Fintype.card X` hypothesis prevents the `5`-transitivity condition
from being vacuously satisfied (otherwise any small action — e.g. `C₃` on
`Fin 3` — would qualify, since there are no injective maps `Fin 5 → X`).

The companion `4`-transitive classification additionally allows
`M₁₁` (`n = 11`, `|G| = 7920`) and `M₂₃` (`n = 23`, `|G| = 10 200 960`).
-/

@[eval_problem]
theorem five_transitive_card_classification
    (G X : Type) [Group G] [Fintype G] [Fintype X]
    [MulAction G X] [FaithfulSMul G X]
    (hcard : 5 ≤ Fintype.card X)
    (h5 : ∀ a b : Fin 5 → X, Function.Injective a → Function.Injective b →
      ∃ g : G, ∀ i, g • a i = b i) :
    let n := Fintype.card X
    Fintype.card G = n.factorial ∨
    (7 ≤ n ∧ Fintype.card G = n.factorial / 2) ∨
    (n = 12 ∧ Fintype.card G = 95040) ∨
    (n = 24 ∧ Fintype.card G = 244823040) := by
  sorry

end GroupTheory
end LeanEval
