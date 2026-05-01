import Mathlib
import EvalTools.Markers

namespace LeanEval
namespace GroupTheory

/-!
Glauberman's `Z*`-theorem (1966).

Let `G` be a finite group and let `t ∈ G` be an *isolated involution*: an
element of order 2 such that no conjugate of `t` (other than `t` itself)
commutes with `t`. Then `t` is central in `G / O(G)`, where `O(G)` is the
largest normal subgroup of `G` of odd order.

Equivalently: there exists a normal subgroup `N ⊴ G` of odd order such that
every multiplicative commutator `g * t * g⁻¹ * t⁻¹` lies in `N`.

The hypothesis below is the *global* form of isolation ("no distinct conjugate
of `t` commutes with `t`"). This is equivalent to the more familiar local form
("`t` is the unique involution of a Sylow 2-subgroup of `C_G(t)`"), but is
self-contained and avoids reference to Sylow theory in the statement.

The proof is a deep application of modular (Brauer) representation theory and
is a cornerstone of the classification of finite simple groups: it is what
allows the local analysis to "fuse" 2-elements via odd-order normal subgroups.
-/

@[eval_problem]
theorem glauberman_zStar
    (G : Type) [Group G] [Fintype G]
    (t : G) (ht1 : t ≠ 1) (ht2 : t * t = 1)
    (hisolated : ∀ g : G, (g * t * g⁻¹) * t = t * (g * t * g⁻¹) →
      g * t * g⁻¹ = t) :
    ∃ N : Subgroup G, N.Normal ∧ Odd (Nat.card N) ∧
      ∀ g : G, g * t * g⁻¹ * t⁻¹ ∈ N := by
  sorry

end GroupTheory
end LeanEval
