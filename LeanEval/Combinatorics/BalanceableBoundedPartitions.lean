import Mathlib.Combinatorics.Enumerative.Partition.Basic
import Mathlib.Algebra.GCDMonoid.Finset
import EvalTools.Markers

namespace LeanEval
namespace Combinatorics

/--
A partition is `k`-bounded if all of its members are at most `k`.

For example, `12 = 3 + 2 + 2 + 2 + 2 + 1` is a `3`-bounded partition
of `12`.
-/
def Bounded {n : Nat} (k : Nat) (p : n.Partition) : Prop :=
  ∀ i ∈ p.parts, i ≤ k

/--
A partition is balanceable if it can be decoposed into two multisets of
the same size.

For example, `12 = (3 + 2 + 1) + (2 + 2 + 2)` is a balanceable partition
of `12`.
-/
def Balanceable {n : Nat} (p : n.Partition) : Prop :=
  ∃ s₁ s₂, s₁ + s₂ = p.parts ∧ s₁.sum = s₂.sum

/--
For any `k`, the smallest `n` such that any `k`-bounded partition of `n` is
also balanceable is given by `2 * lcm(1, ..., k)`.
-/
@[eval_problem]
theorem minimal_boundedImpliesBalanceable (k : Nat) (hk : 0 < k) :
    Minimal (fun n => 0 < n ∧ ∀ p : n.Partition, Bounded k p → Balanceable p) (2 * (Finset.Icc 1 k).lcm id) := by
  sorry

end Combinatorics
end LeanEval
