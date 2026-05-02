import Mathlib.Analysis.Calculus.Deriv.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Deriv
import EvalTools.Markers

namespace LeanEval
namespace Analysis
namespace ODE

open scoped Real

/-!
Dirichlet eigenvalues of `-y'' = λ y` on `[0, π]`.

A nontrivial `C²` solution `y` (defined on some open interval `J` containing `[0, π]`)
of `-y''(x) = λ y(x)` with `y 0 = y π = 0` exists **iff** `λ = n²` for some positive
natural number `n`.

The "if" direction is straightforward (`sin (n · x)` works). The "only if" direction is
the substantive content: it requires casing on the sign of `λ` and ruling out `λ < 0`
(only the zero solution; uses `sinh`/`cosh` linear independence) and `λ = 0` (only the
zero solution), and for `λ > 0` showing that `√λ` must be a positive integer.
-/

/-- **Dirichlet eigenvalue characterization.** A real `λ` is a Dirichlet eigenvalue of
`-y'' = λ y` on `[0, π]` (i.e. there is a nontrivial `C²` solution on some open interval
containing `[0, π]`, vanishing at both endpoints) iff `λ = n²` for some positive natural
number `n`. -/
@[eval_problem]
theorem dirichlet_eigenvalues_eq_nat_sq (lam : ℝ) :
    (∃ (y : ℝ → ℝ) (J : Set ℝ),
        IsOpen J ∧ Set.Icc (0 : ℝ) Real.pi ⊆ J ∧
        (∀ x ∈ J, HasDerivAt y (deriv y x) x) ∧
        (∀ x ∈ J, HasDerivAt (deriv y) (-(lam * y x)) x) ∧
        y 0 = 0 ∧ y Real.pi = 0 ∧
        ∃ x ∈ Set.Ioo (0 : ℝ) Real.pi, y x ≠ 0) ↔
      ∃ n : ℕ, 0 < n ∧ lam = (n : ℝ) ^ 2 := by
  sorry

end ODE
end Analysis
end LeanEval
