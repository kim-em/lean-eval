import Mathlib.Analysis.Convex.Caratheodory
import Mathlib.Analysis.Convex.KreinMilman
import EvalTools.Markers

namespace FormalMathEval
namespace ConvexGeometry

open Set

/-!
Minkowski-Carathéodory theorem in finite-dimensional real normed spaces.

This formulation packages the theorem as a finite extreme-point representation for each point of a
compact convex set, with the expected `finrank + 1` bound on the number of points used.
-/

@[eval_problem]
theorem mem_convexHull_finset_extremePoints_of_mem_compact_convex
    {E : Type*} [NormedAddCommGroup E] [NormedSpace ℝ E] [FiniteDimensional ℝ E]
    {s : Set E} {x : E}
    (hscomp : IsCompact s)
    (hsconv : Convex ℝ s)
    (hx : x ∈ s) :
    ∃ t : Finset E,
      (↑t : Set E) ⊆ s.extremePoints ℝ ∧
      t.card ≤ Module.finrank ℝ E + 1 ∧
      x ∈ convexHull ℝ (↑t : Set E) := by
  sorry

end ConvexGeometry
end FormalMathEval
