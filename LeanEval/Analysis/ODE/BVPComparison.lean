import Mathlib.Analysis.Calculus.Deriv.Basic
import EvalTools.Markers

namespace LeanEval
namespace Analysis
namespace ODE

/-!
Comparison principle for the second-order Dirichlet boundary value problem.

If `u, v` are `C²` on an open interval `J` containing `[0, 1]` and satisfy
  `-u''(x) ≤ -v''(x)` on `(0, 1)`,
together with the boundary inequalities `u 0 ≤ v 0` and `u 1 ≤ v 1`, then `u ≤ v` on
`[0, 1]`.

This is the simplest 1D maximum principle. Direct convex argument: `(u - v)'' ≥ 0` on
`(0, 1)` so `u - v` is convex on `[0, 1]`, hence bounded above by its chord, which is
non-positive at the endpoints. A perturbation proof: `ψ := (u - v) - δ x(1 - x)` is
strictly convex (`ψ'' ≥ 2δ > 0`); a strictly convex function attains its supremum at the
boundary, where `ψ ≤ 0`; let `δ → 0`.
-/

/-- **Comparison principle for the Dirichlet BVP.** If two functions are `C²` on an open
interval `J` containing `[0, 1]`, satisfy `-u'' ≤ -v''` on the interior, and are ordered
at the boundary, then `u ≤ v` throughout `[0, 1]`. -/
@[eval_problem]
theorem bvp_comparison
    (J : Set ℝ) (hJ_open : IsOpen J) (hJ_sub : Set.Icc (0 : ℝ) 1 ⊆ J)
    (u v : ℝ → ℝ)
    (hu : ∀ x ∈ J, HasDerivAt u (deriv u x) x)
    (hu' : ∀ x ∈ J, HasDerivAt (deriv u) (deriv (deriv u) x) x)
    (hv : ∀ x ∈ J, HasDerivAt v (deriv v x) x)
    (hv' : ∀ x ∈ J, HasDerivAt (deriv v) (deriv (deriv v) x) x)
    (hineq : ∀ x ∈ Set.Ioo (0 : ℝ) 1, -deriv (deriv u) x ≤ -deriv (deriv v) x)
    (hu0 : u 0 ≤ v 0) (hu1 : u 1 ≤ v 1) :
    ∀ x ∈ Set.Icc (0 : ℝ) 1, u x ≤ v x := by
  sorry

end ODE
end Analysis
end LeanEval
