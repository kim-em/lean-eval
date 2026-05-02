import Mathlib.Analysis.Calculus.Deriv.Basic
import Mathlib.Analysis.Calculus.FDeriv.Basic
import Mathlib.Analysis.Normed.Algebra.MatrixExponential
import Mathlib.LinearAlgebra.Eigenspace.Basic
import EvalTools.Markers

namespace LeanEval
namespace Analysis
namespace ODE

/-!
Linear stability of `x' = A x` when every eigenvalue of `A` has negative real part.

For `A : Matrix (Fin n) (Fin n) ℂ` such that every (complex) eigenvalue `μ` of `A`
satisfies `μ.re < 0`, every solution of `x' = A x` decays to zero in norm.

Stating this in real coordinates uses the embedding `A : Matrix (Fin n) (Fin n) ℝ ↪
Matrix (Fin n) (Fin n) ℂ` and asks about the *complex* eigenvalues. The proof requires
the matrix exponential, the Jordan / triangularisation form, and a uniform bound of the
form `‖exp (t A)‖ ≤ C · exp(α t)` for some `α < 0`.
-/

open scoped Matrix

/-- **Asymptotic stability of a linear ODE with eigenvalues in the open left half-plane.**

Let `A : Matrix (Fin n) (Fin n) ℝ`. Suppose every (complex) eigenvalue of the
complexification of `A` has strictly negative real part. Then every solution of the
linear ODE `x'(t) = A · x(t)` tends to `0` in norm as `t → ∞`. -/
@[eval_problem]
theorem linear_ode_asymptotic_stability
    (n : ℕ) (A : Matrix (Fin n) (Fin n) ℝ)
    (hA : ∀ μ : ℂ,
        Module.End.HasEigenvalue
          (Matrix.toLin' (A.map (algebraMap ℝ ℂ))) μ → μ.re < 0)
    (x : ℝ → (Fin n → ℝ))
    (hx : ∀ t : ℝ, 0 < t → HasDerivAt x (A.mulVec (x t)) t) :
    Filter.Tendsto (fun t : ℝ => ‖x t‖) Filter.atTop (nhds 0) := by
  sorry

end ODE
end Analysis
end LeanEval
