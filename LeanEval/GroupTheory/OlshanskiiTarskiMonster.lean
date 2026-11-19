import Mathlib
import EvalTools.Markers

namespace LeanEval
namespace GroupTheory

/-!
# Ol'shanskii's Tarski Monster Group Existence Theorem

For every prime $p > 10^{75}$, there exists an infinite group $G$ such that
every proper nontrivial subgroup of $G$ is cyclic of order $p$.

Proved by A. Yu. Ol'shanskii (1979/1980, *Izv. Akad. Nauk SSSR Ser. Mat.* 44;
1982, *Algebra i Logika* 21 / *Mat. Sb.* 118; consolidated in his monograph
*Geometry of Defining Relations in Groups*, Kluwer, 1991). Every such Tarski
monster is an infinite $2$-generated simple group of exponent $p$, providing
striking counterexamples to the Burnside problem and the von Neumann conjecture
on non-amenable groups without non-abelian free subgroups.

The statement requires **zero new definitions** beyond Mathlib (`Nat.Prime`,
`Group`, `Infinite`, `Subgroup`, `IsCyclic`, `Nat.card`).
-/

/-- **Ol'shanskii's Tarski monster group existence theorem.** For every prime
$p > 10^{75}$, there exists an infinite group whose every proper nontrivial
subgroup is cyclic of order $p$. -/
@[eval_problem]
theorem olshanskii_tarski_monster {p : ℕ} (hp : p.Prime) (hgt : 10 ^ 75 < p) :
    ∃ (G : Type) (_ : Group G),
      Infinite G ∧
      ∀ H : Subgroup G, H ≠ ⊥ → H ≠ ⊤ → IsCyclic H ∧ Nat.card H = p := by
  sorry

end GroupTheory
end LeanEval
