import Mathlib.Topology.Homotopy.Contractible
import EvalTools.Markers

namespace LeanEval.Topology

/-!
Bing's house with two rooms is contractible.

We use the construction on p.4 of Allen Hatcher, *Algebraic Topology*.
The three coordinate axes are horizontal, diagonal and vertical towards
the east, northeast and north directions respectively, with the origin
located at the southwest corner.
-/

open Set (Icc Ioo)

/-- Bing's house with two rooms (Hatcher's version) as a subspace of `ℝ × ℝ × ℝ`. -/
def HouseWithTwoRooms : Set (ℝ × ℝ × ℝ) :=
  (Icc 0 4 ×ˢ Icc 0 3 ×ˢ {0, 1, 2} \
    (Ioo 2 3 ×ˢ Ioo 1 2 ×ˢ {0} ∪ Ioo 1 3 ×ˢ Ioo 1 2 ×ˢ {1} ∪ Ioo 1 2 ×ˢ Ioo 1 2 ×ˢ {2})) ∪
  ({1} ×ˢ Icc 1 2 ×ˢ Icc 1 2 ∪ {2} ×ˢ Icc 1 3 ×ˢ Icc 0 2 ∪ {3} ×ˢ Icc 1 2 ×ˢ Icc 0 1 ∪
    Icc 1 2 ×ˢ {1, 2} ×ˢ Icc 1 2 ∪ Icc 2 3 ×ˢ {1, 2} ×ˢ Icc 0 1) ∪
  (Icc 0 4 ×ˢ {0, 3} ×ˢ Icc 0 2 ∪ {0, 4} ×ˢ Icc 0 3 ×ˢ Icc 0 2)

@[eval_problem]
theorem contractibleSpace_houseWithTwoRooms : ContractibleSpace HouseWithTwoRooms := by
  sorry

end LeanEval.Topology
