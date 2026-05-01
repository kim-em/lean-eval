import LeanEval.KnotTheory.Prelude
import EvalTools.Markers

namespace LeanEval
namespace KnotTheory

/-!
# Existence of non-isotopic knots

Distinguishing two knots is genuinely harder than distinguishing two links:
no `lk`-style integral does the job, so any proof has to construct an
ambient-isotopy invariant of single-component knots and compute it on two
explicit parametrizations.
-/

/-- **Existence of a non-isotopic pair of smooth knots.**

There exist two smooth knots in `ℝ³` that are not ambient-isotopic.

*Suggestion.* Take `K₁` to be the **unknot**, parametrized as the round
unit circle in the `xy`-plane, and `K₂` to be the **right-handed trefoil**,
parametrized for instance by

  `t ↦ (sin t + 2 sin (2 t), cos t − 2 cos (2 t), −sin (3 t))`

(this is a smooth, 2π-periodic immersion, and it is injective on `[0, 2π)`).

To distinguish them, you must construct an ambient-isotopy invariant of
knots. Two computationally tractable options, each fully developed from
elementary ingredients:

* The **knot determinant** `|Δ_K(−1)|`, where `Δ_K ∈ ℤ[t, t⁻¹]` is the
  Alexander polynomial. The unknot has determinant `1`; the trefoil has
  determinant `3`.
* The number of **Fox 3-colorings** of any diagram of `K`, which counts
  homomorphisms from the knot group to the dihedral group `D₃` and is an
  isotopy invariant. The unknot admits only monochromatic 3-colorings
  (3 of them); the trefoil admits 9.

See <https://en.wikipedia.org/wiki/Knot_invariant> for a survey. -/
@[eval_problem]
theorem exists_nonisotopic_knots : ∃ K₁ K₂ : Knot, ¬ K₁.Isotopic K₂ := by
  sorry

end KnotTheory
end LeanEval
