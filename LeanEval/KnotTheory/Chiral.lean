import LeanEval.KnotTheory.Prelude
import EvalTools.Markers

namespace LeanEval
namespace KnotTheory

/-!
# Existence of a chiral knot

The challenge problem of the knot-theory benchmark. Unlike the previous two
problems — where the relevant invariant is suggested explicitly — proving
chirality requires an invariant *that is not preserved under reflection*,
and choosing the right such invariant is part of the problem.
-/

/-- **Existence of a chiral oriented smooth knot.**

There exists an oriented smooth knot in `ℝ³` that is not ambient-isotopic
to its mirror image (the reflection of the image through the `xy`-plane).

*Suggestion.* The right-handed trefoil is chiral. Parametrize it for
instance as

  `t ↦ (sin t + 2 sin (2 t), cos t − 2 cos (2 t), −sin (3 t))`.

Here chirality is understood in the orientation-sensitive sense induced by
the benchmark's notion of isotopy. Proving chirality therefore requires an
ambient-isotopy invariant that takes *different* values on a knot and its
mirror image. The figure-eight knot *is* isotopic to its mirror in the usual
unoriented sense, so the invariant must be sensitive to chirality — in
particular, the knot determinant and the Alexander polynomial alone do *not*
suffice (both are mirror-symmetric).

Standard chirality-detecting invariants:

* The **knot signature** `σ(K) ∈ ℤ`, computed from a Seifert matrix
  `V` as the signature of `V + Vᵀ`. Mirroring negates the signature, so
  any knot with `σ(K) ≠ 0` is chiral. The right-handed trefoil has
  `σ = −2`.
* The **Jones polynomial** `V_K(t) ∈ ℤ[t^{1/2}, t^{-1/2}]`. Mirroring
  sends `V_K(t)` to `V_K(t⁻¹)`, so any knot whose Jones polynomial is not
  symmetric under `t ↔ t⁻¹` is chiral. The right-handed trefoil has
  `V_K(t) = −t^{−4} + t^{−3} + t^{−1}`.

See <https://en.wikipedia.org/wiki/Chirality_(mathematics)> and
<https://en.wikipedia.org/wiki/Trefoil_knot>. -/
@[eval_problem]
theorem exists_chiral_knot : ∃ K : Knot, K.Chiral := by
  sorry

end KnotTheory
end LeanEval
