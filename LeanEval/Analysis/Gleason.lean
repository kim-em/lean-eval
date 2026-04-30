import Mathlib.Analysis.InnerProductSpace.Positive
import Mathlib.Analysis.InnerProductSpace.l2Space
import Mathlib.LinearAlgebra.Trace
import EvalTools.Markers

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

/-- An orthogonal projection on `H`: a self-adjoint idempotent continuous linear map. -/
def IsOrthProj (P : H →L[ℂ] H) : Prop :=
  IsIdempotentElem P ∧ IsSelfAdjoint P

/-- A frame function on the projection lattice: non-negative on orthogonal projections,
finitely additive on orthogonal pairs, and `μ I = 1`. (In finite dimensions any countable
orthogonal family is finite, so finite additivity already yields countable additivity.) -/
structure FrameFunction (H : Type*) [NormedAddCommGroup H] [InnerProductSpace ℂ H]
    [CompleteSpace H] where
  μ : (H →L[ℂ] H) → ℝ
  nonneg : ∀ P : H →L[ℂ] H, IsOrthProj P → 0 ≤ μ P
  additive : ∀ P Q : H →L[ℂ] H, IsOrthProj P → IsOrthProj Q → P * Q = 0 →
    μ (P + Q) = μ P + μ Q
  normalized : μ (1 : H →L[ℂ] H) = 1

/-- The real part of the complex trace of a continuous linear operator on a
finite-dimensional complex inner product space. -/
noncomputable def reTr [FiniteDimensional ℂ H] (A : H →L[ℂ] H) : ℝ :=
  (LinearMap.trace ℂ H A.toLinearMap).re

/-- **Gleason's theorem**, finite-dimensional version. For `dim H ≥ 3`, every frame
function on the projection lattice of `H` is given by `P ↦ re Tr(ρ P)` for the unique
density operator `ρ` (positive, `re Tr ρ = 1`). -/
@[eval_problem]
theorem gleason_theorem_finite
    {H : Type*} [NormedAddCommGroup H] [InnerProductSpace ℂ H]
      [CompleteSpace H] [FiniteDimensional ℂ H]
    (hdim : 3 ≤ Module.finrank ℂ H)
    (f : FrameFunction H) :
    ∃! ρ : H →L[ℂ] H,
      ContinuousLinearMap.IsPositive ρ ∧
      reTr ρ = 1 ∧
      ∀ P : H →L[ℂ] H, IsOrthProj P → f.μ P = reTr (ρ * P) := by
  sorry

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

/-- **Gleason's theorem**, separable Hilbert space version (Gleason's original 1957
formulation). For a separable complex Hilbert space `H` of dimension at least `3`, every
frame function on the unit sphere of `H` is given by `x ↦ re ⟨x, ρ x⟩` for some positive
bounded operator `ρ`. (The Lean conclusion does not separately assert trace-class /
`Tr ρ = 1`; see the file docstring.) -/
@[eval_problem]
theorem gleason_theorem_separable
    {H : Type*} [NormedAddCommGroup H] [InnerProductSpace ℂ H]
      [CompleteSpace H] [TopologicalSpace.SeparableSpace H]
    (hdim : 3 ≤ Module.rank ℂ H)
    (f : SphereFrameFunction H) :
    ∃ ρ : H →L[ℂ] H,
      ContinuousLinearMap.IsPositive ρ ∧
      ∀ x : Metric.sphere (0 : H) 1,
        f.f x = (inner ℂ (x : H) (ρ (x : H))).re := by
  sorry

end Analysis
end LeanEval
