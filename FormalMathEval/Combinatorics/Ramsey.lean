import Mathlib.Combinatorics.SimpleGraph.Clique
import EvalTools.Markers

namespace FormalMathEval
namespace Combinatorics

open SimpleGraph

/-!
Finite Ramsey theorem for graphs, phrased as the existence of a finite complete graph whose edges,
under any red/blue colouring, contain either a red `r`-clique or a blue `s`-clique.

We encode a 2-colouring by a simple graph `G` on `Fin n`; the red edges are the edges of `G` and
the blue edges are the edges of `Gᶜ`.
-/

@[eval_problem]
theorem finite_graph_ramsey_theorem :
    ∀ r s : ℕ, 2 ≤ r → 2 ≤ s → ∃ n : ℕ, ∀ G : SimpleGraph (Fin n), ¬ G.CliqueFree r ∨ ¬ Gᶜ.CliqueFree s := by
  sorry

end Combinatorics
end FormalMathEval
