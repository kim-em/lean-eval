import Mathlib

namespace LeanEval
namespace Analysis

/-!
Gleason's theorem (1957).

Let `H` be a complex Hilbert space of dimension at least `3`. Every non-negative function
on the orthogonal projections of `H` that is countably additive on orthogonal families and
sends the identity to `1` is given by `P ↦ Tr(ρ P)` for a unique density operator `ρ`
(positive trace-class operator with trace `1`).

This file states two versions:

1. `gleason_theorem_finite`: `H` is finite-dimensional. The trace-class condition is
   automatic, additivity on orthogonal pairs already implies countable additivity, and
   the conclusion uses the standard finite trace `LinearMap.trace`.

2. `gleason_theorem_separable`: `H` is separable. Stated in Gleason's original "frame
   function on the unit sphere" form: a non-negative function on the unit sphere that
   sums to `1` along every Hilbert basis is given by `x ↦ re ⟨x, ρ x⟩` for some positive
   bounded operator `ρ`. (The Lean conclusion does not assert that `ρ` is trace-class
   with `Tr ρ = 1`; stating that would require trace-class infrastructure not yet at
   this Mathlib pin. It is recoverable by combining the conclusion with `f.basis_sum`.)
-/

variable {H : Type*} [NormedAddCommGroup H] [InnerProductSpace ℂ H] [CompleteSpace H]

/-- A frame function on the unit sphere of `H` (Gleason's original 1957 definition).
A non-negative function on unit vectors whose values sum to `1` along every Hilbert
basis. -/
structure SphereFrameFunction (H : Type*) [NormedAddCommGroup H] [InnerProductSpace ℂ H]
    [CompleteSpace H] where
  f : Metric.sphere (0 : H) 1 → ℝ
  nonneg : ∀ x : Metric.sphere (0 : H) 1, 0 ≤ f x
  basis_sum : ∀ {ι : Type*} (b : HilbertBasis ι ℂ H),
    HasSum
      (fun i : ι => f ⟨b i, mem_sphere_zero_iff_norm.mpr (b.orthonormal.norm_eq_one i)⟩)
      1



end Analysis
end LeanEval
