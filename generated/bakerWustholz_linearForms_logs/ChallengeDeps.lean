import Mathlib

/-!
# The Baker–Wüstholz theorem on linear forms in logarithms

Reference: A. Baker and G. Wüstholz, *Logarithmic forms and group varieties*,
J. reine angew. Math. **442** (1993), 19–62. In particular, their "main theorem"
is a refinement of the 1966-68 Baker bound, with the outer exponent on `log B`
essentially `1` rather than `(2n+1)²`.

## Statement conventions

* `α₁, …, αₙ` are nonzero elements of a number field `K`. We work through a
  ring-hom embedding `φ : K →+* ℂ`, and use `Complex.log` (principal branch)
  for the logs of the images.
* `d := Module.finrank ℚ K` is the field degree.
* `h(α) := Height.logHeight₁ α / d` is the **normalized** logarithmic Weil
  height. (Mathlib's `logHeight₁` is the unnormalized product-over-places
  sum; dividing by `d` gives the classical absolute height.)
* `h'(α) := max(h(α), |log φ(α)| / d, 1 / d)` is the **modified height** used
  by Baker–Wüstholz. The extra terms handle the case where `α` is very close
  to 1 (so `h(α)` is small) or where the chosen log determination is large.
* `B := max(|b₁|, …, |bₙ|, 2)` is the maximum coefficient (clamped to 2 so
  `log B > 0`).
* `C(n, d) := 18 · (n + 1)! · n^(n+1) · (32d)^(n+2) · log(2nd)` is the
  Baker–Wüstholz constant.
-/

open Complex

namespace BakerWustholz

/-- The Baker–Wüstholz constant
`C(n, d) = 18 · (n + 1)! · n^{n+1} · (32 d)^{n+2} · log (2nd)`. -/
noncomputable def C (n d : ℕ) : ℝ :=
  18 * (n + 1).factorial * (n : ℝ) ^ (n + 1) *
    (32 * (d : ℝ)) ^ (n + 2) * Real.log (2 * n * d)

/-- The modified height `h'(α) = max(h(α), |log φ(α)| / d, 1 / d)` where
`h(α) := logHeight₁ α / d` is the normalized logarithmic Weil height. -/
noncomputable def modifiedHeight
    {K : Type*} [Field K] [NumberField K] (φ : K →+* ℂ) (α : K) : ℝ :=
  let d : ℝ := Module.finrank ℚ K
  max (Height.logHeight₁ α / d) (max (‖Complex.log (φ α)‖ / d) (1 / d))

end BakerWustholz
