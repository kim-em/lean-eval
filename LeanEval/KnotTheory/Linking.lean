import LeanEval.KnotTheory.Prelude
import EvalTools.Markers

namespace LeanEval
namespace KnotTheory

/-!
# Existence of non-isotopic two-component links

A warmup for the knot-theory benchmark. Two-component links are easier to
distinguish than knots because the *Gauss linking integral* is a real-valued
ambient-isotopy invariant defined by an explicit double integral over the
two parametrizations — no diagrammatic machinery needed.
-/

/-- **Existence of a non-isotopic pair of oriented two-component links.**

There exist two oriented smooth two-component links in `ℝ³` that are not
ambient-isotopic.

*Suggestion.* Take `L₁` to be the **unlink** — for instance, the two unit
circles in the planes `z = 0` and `z = 2`, both centered on the `z`-axis —
and `L₂` to be the **Hopf link** — for instance, the unit circle in the
`xy`-plane together with the unit circle in the `xz`-plane shifted by `(1, 0, 0)`.

To distinguish them, use the **Gauss linking integral**

  `lk(K, L) = (1 / (4π)) ∫₀^{2π} ∫₀^{2π}`
              `⟨K(s) − L(t), K′(s) × L′(t)⟩ / ‖K(s) − L(t)‖³ ds dt`,

which is well-defined when the components have disjoint images, takes the
value `0` on the unlink and `±1` on the Hopf link depending on the chosen
orientations, and is invariant under ambient isotopy of the oriented link.
(Invariance follows from a Stokes-style computation: the integrand is the
pullback of a closed 2-form on `ℝ³ \ {0}`.)

See <https://en.wikipedia.org/wiki/Linking_number> for a reference. -/
@[eval_problem]
theorem exists_nonisotopic_link : ∃ L₁ L₂ : TwoLink, ¬ L₁.Isotopic L₂ := by
  sorry

end KnotTheory
end LeanEval
