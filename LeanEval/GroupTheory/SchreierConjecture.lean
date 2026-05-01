import Mathlib
import EvalTools.Markers

namespace LeanEval
namespace GroupTheory

/-!
Schreier's conjecture (theorem, modulo CFSG).

For every finite non-abelian simple group `S`, the outer automorphism group
`Out(S) := Aut(S) / Inn(S)` is solvable.

This was conjectured by Schreier in the 1920s. It is verified case-by-case
through the classification of finite simple groups: for each family
(alternating, classical, exceptional Lie type, sporadic) one inspects `Out(S)`
and observes solvability. No CFSG-free proof is known.

`MulAut.conj : S →* MulAut S` sends `s ↦ (conjugation by s)`; its range is
`Inn(S)`. The instance below records that `Inn(S)` is normal in `Aut(S)`,
which is needed to form the quotient.
-/

/-- `Inn(S)` is a normal subgroup of `Aut(S)`: the conjugate of `conj s` by an
automorphism `α` is `conj (α s)`. -/
instance innNormal (S : Type*) [Group S] :
    ((MulAut.conj : S →* MulAut S).range).Normal where
  conj_mem := by
    rintro _ ⟨s, rfl⟩ α
    refine ⟨α s, ?_⟩
    ext x
    simp [MulAut.conj_apply, map_mul, map_inv, MulEquiv.apply_symm_apply]

@[eval_problem]
theorem schreier_conjecture
    (S : Type) [Group S] [Fintype S] [IsSimpleGroup S]
    (hS : ∃ a b : S, ¬ Commute a b) :
    IsSolvable (MulAut S ⧸ (MulAut.conj : S →* MulAut S).range) := by
  sorry

end GroupTheory
end LeanEval
