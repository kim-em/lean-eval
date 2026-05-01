import Mathlib.Analysis.InnerProductSpace.PiL2
import Mathlib.Analysis.Calculus.ContDiff.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic

namespace LeanEval
namespace KnotTheory

/-!
# Smooth knots, links, ambient isotopy, and chirality

Minimal definitions to support the three knot-theory benchmark problems
(`Linking`, `NonIsotopicKnots`, `Chiral`). Mathlib has essentially no knot
theory, so we set up just enough infrastructure to state the questions
faithfully in terms of smooth maps `S¹ → ℝ³` and ambient isotopies of `ℝ³`.

A *knot* is a smooth, 2π-periodic, injective immersion `ℝ → ℝ³`. A
*two-component link* is a pair of knots with disjoint images. An *ambient
isotopy* is a smooth one-parameter family of diffeomorphisms of `ℝ³`
starting at the identity, presented here as a forward map and an inverse
map jointly smooth in `(t, x)`.

Two knots / links are *isotopic* if some ambient isotopy carries the image
of the first to the image of the second. A knot is *chiral* if its image is
not isotopic to its mirror image (under reflection through the `xy`-plane).

These definitions trade some Mathlib idiomaticity for being self-contained
and easy to read; in particular, we do not go through `Diffeomorph` or
`ContMDiff` on a manifold structure for `ℝ³`, since `ContDiff ℝ ⊤` over the
ambient normed space says exactly what we need.
-/

/-- The ambient space `ℝ³`, as a Euclidean inner-product space. -/
abbrev R3 : Type := EuclideanSpace ℝ (Fin 3)

/-- A smooth knot in `ℝ³`: a 2π-periodic, smooth, injective immersion. -/
structure Knot where
  /-- The parametrizing map. -/
  curve : ℝ → R3
  /-- The map is smooth. -/
  smooth : ContDiff ℝ (⊤ : ℕ∞) curve
  /-- The map has period `2π`. -/
  periodic : ∀ t, curve (t + 2 * Real.pi) = curve t
  /-- The map is injective on a fundamental period. -/
  injOn : Set.InjOn curve (Set.Ico 0 (2 * Real.pi))
  /-- The map is an immersion (its derivative is everywhere nonzero). -/
  immersion : ∀ t, deriv curve t ≠ 0

/-- A two-component smooth link in `ℝ³`: a pair of knots with disjoint
images. -/
structure TwoLink where
  /-- The first component. -/
  K : Knot
  /-- The second component. -/
  L : Knot
  /-- The two components have disjoint images in `ℝ³`. -/
  disjoint : Disjoint (Set.range K.curve) (Set.range L.curve)

/-- A smooth ambient isotopy of `ℝ³`: a one-parameter family `H t : ℝ³ → ℝ³`
of diffeomorphisms, jointly smooth in `(t, x)`, starting at the identity.
The inverse family `Hinv` is also jointly smooth. -/
structure AmbientIsotopy where
  /-- The forward family. -/
  H : ℝ → R3 → R3
  /-- The inverse family. -/
  Hinv : ℝ → R3 → R3
  /-- The forward family is jointly smooth in `(t, x)`. -/
  smooth : ContDiff ℝ (⊤ : ℕ∞) (Function.uncurry H)
  /-- The inverse family is jointly smooth in `(t, x)`. -/
  smooth_inv : ContDiff ℝ (⊤ : ℕ∞) (Function.uncurry Hinv)
  /-- `Hinv t` is a left inverse of `H t`. -/
  inv_left : ∀ t x, Hinv t (H t x) = x
  /-- `Hinv t` is a right inverse of `H t`. -/
  inv_right : ∀ t x, H t (Hinv t x) = x
  /-- The isotopy starts at the identity. -/
  start : H 0 = id

/-- Two knots are ambient-isotopic if some ambient isotopy of `ℝ³` carries
the image of the first to the image of the second. -/
def Knot.Isotopic (K₁ K₂ : Knot) : Prop :=
  ∃ Φ : AmbientIsotopy, Φ.H 1 '' Set.range K₁.curve = Set.range K₂.curve

/-- Two two-component links are ambient-isotopic if a single ambient isotopy
carries each component image to the corresponding component image. -/
def TwoLink.Isotopic (L₁ L₂ : TwoLink) : Prop :=
  ∃ Φ : AmbientIsotopy,
    Φ.H 1 '' Set.range L₁.K.curve = Set.range L₂.K.curve ∧
    Φ.H 1 '' Set.range L₁.L.curve = Set.range L₂.L.curve

/-- Reflection through the `xy`-plane in `ℝ³`: `(x, y, z) ↦ (x, y, -z)`. -/
def reflectZ (p : R3) : R3 :=
  WithLp.toLp 2 (fun i : Fin 3 => if i = 2 then -p.ofLp i else p.ofLp i)

/-- A knot is *chiral* if its image is not ambient-isotopic to its mirror
image (the reflection of the image through the `xy`-plane). -/
def Knot.Chiral (K : Knot) : Prop :=
  ¬ ∃ Φ : AmbientIsotopy,
    Φ.H 1 '' Set.range K.curve = reflectZ '' Set.range K.curve

end KnotTheory
end LeanEval
