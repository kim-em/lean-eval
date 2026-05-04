import Mathlib.Analysis.Calculus.Deriv.Basic
import EvalTools.Markers

namespace LeanEval
namespace Analysis
namespace ODE

/-!
Sturm separation theorem.

Two linearly independent (in the Wronskian sense) solutions of the second-order linear
homogeneous equation
  `y'' + p(x) y' + q(x) y = 0`
have interlacing zeros: between any two consecutive zeros of one solution lies exactly
one zero of the other.

Hypotheses are localized to an open interval `J` containing `[a, b]`.

Proof sketch: on `(a, b)` the function `f := y₂ / y₁` is well-defined (since `y₁ ≠ 0` on
the open interval) and differentiable; its derivative equals `-W / y₁²` where `W` is the
Wronskian, which has constant sign. So `f` is strictly monotone on `(a, b)`. The boundary
values force `y₂` to vanish in `(a, b)`, and strict monotonicity shows there can be at
most one such zero.
-/

/-- **Sturm separation theorem.** Suppose `y₁, y₂ : ℝ → ℝ` are `C²` solutions on an open
interval `J` containing `[a, b]` of the linear homogeneous ODE `y'' + p y' + q y = 0`
with `p, q` continuous on `J`, and their Wronskian is nonzero at some point of `J`. If
`a < b ∈ J` are consecutive zeros of `y₁` (i.e. `y₁ a = y₁ b = 0` and `y₁ x ≠ 0` on
`(a, b)`), then `y₂` has exactly one zero in `(a, b)`. -/
@[eval_problem]
theorem sturm_separation
    (p q y₁ y₂ : ℝ → ℝ) (a b : ℝ) (hab : a < b)
    (J : Set ℝ) (hJ_open : IsOpen J) (hJ_conn : IsPreconnected J)
    (hJ_sub : Set.Icc a b ⊆ J)
    (hp : ContinuousOn p J) (hq : ContinuousOn q J)
    (hy₁ : ∀ x ∈ J, HasDerivAt y₁ (deriv y₁ x) x)
    (hy₁' : ∀ x ∈ J, HasDerivAt (deriv y₁) (-(p x * deriv y₁ x + q x * y₁ x)) x)
    (hy₂ : ∀ x ∈ J, HasDerivAt y₂ (deriv y₂ x) x)
    (hy₂' : ∀ x ∈ J, HasDerivAt (deriv y₂) (-(p x * deriv y₂ x + q x * y₂ x)) x)
    (hW : ∃ x₀ ∈ J, y₁ x₀ * deriv y₂ x₀ - y₂ x₀ * deriv y₁ x₀ ≠ 0)
    (hza : y₁ a = 0) (hzb : y₁ b = 0)
    (hne : ∀ x ∈ Set.Ioo a b, y₁ x ≠ 0) :
    ∃! c, c ∈ Set.Ioo a b ∧ y₂ c = 0 := by
  sorry

end ODE
end Analysis
end LeanEval
