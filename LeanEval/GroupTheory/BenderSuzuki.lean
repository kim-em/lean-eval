import Mathlib
import EvalTools.Markers
import LeanEval.GroupTheory.Defs.Suzuki

namespace LeanEval
namespace GroupTheory

open LeanEval.GroupTheory.Defs

/-!
# Bender–Suzuki theorem on finite simple groups with a strongly-embedded subgroup

Let `X` be a finite simple group with a strongly-embedded subgroup `M`.
Then `X` is `PSL(2, 2ⁿ)`, `Sz(2^(2n+1))` or `PSU(3, 2ⁿ)`.

D. Gorenstein, R. Lyons, and R. Solomon, "The classification of the finite simple groups, Number 2"

Introduces `Defs/Suzuki.lean`.
-/

/-- **Bender–Suzuki theorem.** -/
@[eval_problem]
theorem bender_suzuki {X : Type*} [Group X] [Finite X] [IsSimpleGroup X]
    (M : Subgroup X) (h : IsStronglyEmbedded M) :
    IsSimpleBenderGroup X := by
  sorry

end GroupTheory
end LeanEval
