import Mathlib.Combinatorics.SimpleGraph.Cayley
import Mathlib.Combinatorics.SimpleGraph.Connectivity.Connected
import Mathlib.Algebra.Group.Subgroup.Lattice
import EvalTools.Markers

namespace LeanEval
namespace Combinatorics

/-!
A Cayley graph is connected if and only if its generators generate the group.

The Cayley graph of a group `G` with generators `S` has vertex set `G` and an edge between
`x` and `y` whenever `x * g = y` for some `g ∈ S`. This theorem characterises connectivity:
the Cayley graph is connected if and only if `S` generates `G` as a group. The forward
direction constructs a path from `1` to any `g ∈ G` via the generators; the reverse shows
that any path in the graph corresponds to a product of generators.

This is a foundational result in geometric group theory, connecting algebraic generation
to graph-theoretic connectivity.
-/

@[eval_problem]
theorem mulCayley_connected_iff_closure_eq_top
    {G : Type*} [Group G]
    (S : Set G) :
    (SimpleGraph.mulCayley S).Connected ↔ Subgroup.closure S = ⊤ := by
  sorry

end Combinatorics
end LeanEval
