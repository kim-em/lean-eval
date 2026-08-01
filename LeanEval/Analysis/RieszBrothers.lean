import Mathlib.Analysis.Fourier.AddCircle
import Mathlib.Analysis.Normed.Operator.Mul
import Mathlib.MeasureTheory.Measure.Complex
import Mathlib.MeasureTheory.VectorMeasure.Decomposition.RadonNikodym
import Mathlib.MeasureTheory.VectorMeasure.Integral
import EvalTools.Markers

namespace LeanEval
namespace Analysis

/-!
# Riesz brothers' theorem

The Riesz brothers' theorem says that a complex Borel measure on the circle
whose positive analytic moments vanish is absolutely continuous with respect to
Haar measure.

-/

open MeasureTheory

/-- **Riesz brothers' theorem.** Let `μ` be a complex Borel measure on
the unit circle such that `∫ z^n dμ = 0` for every `n ≥ 1`. Then `μ` is
absolutely continuous with respect to Haar measure. The usual density
formulation follows by applying the Radon–Nikodym theorem to this conclusion;
the hypothesis transfers the Fourier-vanishing property to that density. This
corollary is not part of the formal statement here. -/
@[eval_problem]
theorem riesz_brothers_theorem (μ : ComplexMeasure UnitAddCircle)
    (hμ : ∀ n : ℕ, 1 ≤ n → ∫ᵛ z, fourier n z ∂[ContinuousLinearMap.mul ℝ ℂ; μ] = 0) :
    μ ≪ᵥ AddCircle.haarAddCircle.toENNRealVectorMeasure := by
  sorry

end Analysis
end LeanEval
