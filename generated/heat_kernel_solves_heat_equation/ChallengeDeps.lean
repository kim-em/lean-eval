import Mathlib

namespace LeanEval
namespace Analysis
namespace ODE

/-!
The Gaussian heat kernel solves the 1D heat equation.

Define
  `u(t, x) = (4 π t)^(-1/2) · ∫_ℝ exp(-(x - y)² / (4 t)) · f(y) dy`
for `t > 0`, and extend by `u(t, x) := f x` for `t ≤ 0`. Then on `(0, ∞) × ℝ` we have
  `∂_t u = ∂_x² u`,
and `u(t, x) → f x` as `t ↓ 0` for every `x`.

This is a substantial benchmark because it exercises differentiation under the integral
sign, the explicit Gaussian integral evaluation, approximate-identity arguments for the
initial trace, and the heat-PDE identity satisfied by the kernel itself.

The PDE statement asserts the existence of the spatial first and second derivatives at
each `(t, x)` with `t > 0`, and equates the time derivative of `u` to the spatial second
derivative. Stating things via `HasDerivAt` (rather than relying on `deriv` returning `0`
silently when the derivative does not exist) ensures the Lean statement matches the
intended PDE.
-/

open Real MeasureTheory

/-- The 1D Gaussian heat kernel. Extended by `f x` for `t ≤ 0` so that it is a global
function `ℝ × ℝ → ℝ`; the PDE statement only constrains its behaviour on `t > 0`. -/
noncomputable def heatSolution (f : ℝ → ℝ) (t x : ℝ) : ℝ :=
  if 0 < t then
    (4 * Real.pi * t)⁻¹ ^ ((1 : ℝ) / 2) *
      ∫ y : ℝ, Real.exp (-((x - y) ^ 2) / (4 * t)) * f y
  else
    f x



end ODE
end Analysis
end LeanEval
