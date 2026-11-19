import Mathlib

namespace LeanEval
namespace NumberTheory
namespace RamanujanTauProblem

/-!
# Ramanujan's conjecture for the τ-function (Deligne's theorem)

The Ramanujan τ-function is defined by the Fourier expansion
`Δ = ∑_{n ≥ 1} τ(n) qⁿ` of the modular discriminant
`Δ(z) = η(z)²⁴ = q ∏_{n ≥ 1} (1 - qⁿ)²⁴`, the normalised cusp form of weight
`12` and level `1`. Ramanujan (1916) conjectured that `|τ(p)| ≤ 2 p^(11/2)`
for every prime `p`, and Deligne proved it in 1974 using his proof of the Weil
conjectures. This bound is due to Ramanujan alone; the Ramanujan–Petersson
conjecture is Petersson's generalisation to all cuspidal Hecke eigenforms.

Here `τ n` is the `n`-th `q`-expansion coefficient of mathlib's
`ModularForm.discriminant`. The coefficients are a priori complex, so the
bound is on the complex norm `‖τ p‖`.
-/

open ModularForm UpperHalfPlane

/-- The Ramanujan τ-function: the `n`-th `q`-expansion coefficient of the
modular discriminant `Δ = η²⁴`. -/
noncomputable def τ (n : ℕ) : ℂ := (qExpansion 1 discriminant).coeff n





end RamanujanTauProblem
end NumberTheory
end LeanEval
