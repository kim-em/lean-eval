import Mathlib.Analysis.Calculus.Deriv.Basic
import Mathlib.Analysis.SpecialFunctions.Pow.Real
import EvalTools.Markers

namespace LeanEval
namespace Analysis
namespace ODE

/-!
Polynomial decay of `y' = -y³`.

The differential equation `y'(t) = -(y t)³` with `y 0 = 1` has the explicit solution
`y(t) = 1/√(1 + 2t)` on `[0, ∞)`. This benchmark asks for the asymptotic rate
`y t · √t → 1/√2` as `t → ∞`, given only the ODE and the initial condition.

The interesting content is not the explicit form (a hint) but the asymptotic statement:
the prover must combine an ODE hypothesis with a limit calculation. The ODE pins down `y`
uniquely on `[0, ∞)`, and the asymptotic follows from the closed form.
-/

open Filter Topology

/-- Asymptotic decay rate for `y' = -y³, y(0) = 1`: the solution satisfies
`y t · √t → 1/√2` as `t → ∞`. -/
@[eval_problem]
theorem cubic_decay_asymptotic
    (y : ℝ → ℝ) (hy_diff : ∀ t : ℝ, 0 < t → HasDerivAt y (-(y t) ^ 3) t)
    (hy_cont : ContinuousWithinAt y (Set.Ici 0) 0)
    (hy0 : y 0 = 1) :
    Tendsto (fun t : ℝ => y t * Real.sqrt t) atTop (𝓝 (1 / Real.sqrt 2)) := by
  sorry

end ODE
end Analysis
end LeanEval
