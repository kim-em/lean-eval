import Mathlib
import EvalTools.Markers

namespace LeanEval
namespace GroupTheory

/-!
# Zelmanov's Solution of the Restricted Burnside Problem

For all integers $m, n \ge 1$, there exists a uniform upper bound
$B \in \mathbb{N}$ such that every finite $m$-generated group $Q$ of exponent
dividing $n$ has cardinality $|Q| \le B$.

Proved by Efim Zelmanov (1990, *Izv. Akad. Nauk SSSR Ser. Mat.* 54; 1991,
*Mat. Sb.* 182), building on the Hall–Higman reduction (1956, *Proc. London
Math. Soc.* 6) and Kostrikin's theorem for prime exponents; Zelmanov received
the Fields Medal in 1994 in part for this work.

The statement requires **zero new definitions** beyond Mathlib (`Group`,
`Finite`, `Fin`, `Subgroup.closure`, `Set.range`, `Nat.card`).
-/

/-- **Zelmanov's solution of the restricted Burnside problem.** For all
$m, n \ge 1$, there exists $B \in \mathbb{N}$ bounding the cardinality of
every finite $m$-generated group of exponent dividing $n$. -/
@[eval_problem]
theorem zelmanov_restricted_burnside {m n : ℕ} (hm : 1 ≤ m) (hn : 1 ≤ n) :
    ∃ B : ℕ, ∀ (Q : Type) [Group Q] [Finite Q],
      (∃ g : Fin m → Q, Subgroup.closure (Set.range g) = ⊤) →
      (∀ x : Q, x ^ n = 1) →
      Nat.card Q ≤ B := by
  sorry

end GroupTheory
end LeanEval
