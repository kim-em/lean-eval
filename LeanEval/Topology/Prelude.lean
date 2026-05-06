import Mathlib.Analysis.Complex.Circle
import Mathlib.Analysis.InnerProductSpace.PiL2
import EvalTools.Markers

/-!
# Basic definitions in topology

In this file we define a representative surface in each homeomorphism class of surfaces by
gluing certain arcs in the boundary of the unit disc.

We also define a representative 3-dimensional handlebody for each genus.
See https://en.wikipedia.org/wiki/Handlebody#3-dimensional_handlebodies.

We pose it as a LeanEval problem to show that the boundary of the handlebody is homeomorphic
to the corresponding representative surface.
-/

namespace Complex

/-- The closed unit disc in the complex plane. -/
abbrev ClosedUnitDisc : Type := Metric.closedBall (0 : ℂ) 1

/-- The boundary point exp(2πir) on the boundary of the closed unit disc in the complex plane. -/
noncomputable def ClosedUnitDisc.bdyPtOfReal (r : ℝ) : ClosedUnitDisc :=
  ⟨r.fourierChar, r.fourierChar.2.le⟩

end Complex

namespace LeanEval.Topology

namespace Surface

open Complex Set

/-- The representative orientable surface homeomorphic to a closed orientable genus `p`
surface with `n` discs removed (if `p` and `n` are not both zero), obtained by identifying
the boundary of a disc in the pattern `a₁b₁a₁⁻¹b₁⁻¹⋯aₚbₚaₚ⁻¹bₚ⁻¹c₁h₁c₁⁻¹⋯cₙhₙcₙ⁻¹`. -/
inductive OrientableRel (p n : ℕ) : ClosedUnitDisc → ClosedUnitDisc → Prop
  | a (x : Icc (0 : ℝ) 1) (i : Fin p) : OrientableRel p n
      (.bdyPtOfReal <| (4 * i + x) / (4 * p + 3 * n))
      (.bdyPtOfReal <| (4 * i + 3 - x) / (4 * p + 3 * n))
  | b (x : Icc (0 : ℝ) 1) (i : Fin p) : OrientableRel p n
      (.bdyPtOfReal <| (4 * i + 1 + x) / (4 * p + 3 * n))
      (.bdyPtOfReal <| (4 * i + 4 - x) / (4 * p + 3 * n))
  | c (x : Icc (0 : ℝ) 1) (i : Fin n) : OrientableRel p n
      (.bdyPtOfReal <| - (3 * i + x) / (4 * p + 3 * n))
      (.bdyPtOfReal <| - (3 * i + 3 - x) / (4 * p + 3 * n))

/-- The representative non-orientable surface homeomorphic to a direct sum of `p` projective
planes with `n` discs removed, obtained by identifying the boundary of a disc in the pattern
`a₁a₁⋯aₚaₚc₁h₁c₁⁻¹⋯cₙhₙcₙ⁻¹`. -/
inductive NonOrientableRel (p n : ℕ) : ClosedUnitDisc → ClosedUnitDisc → Prop
  | a (x : Icc (0 : ℝ) 1) (i : Fin p) : NonOrientableRel p n
      (.bdyPtOfReal <| (2 * i + x) / (2 * p + 3 * n))
      (.bdyPtOfReal <| (2 * i + 1 + x) / (2 * p + 3 * n))
  | c (x : Icc (0 : ℝ) 1) (i : Fin n) : NonOrientableRel p n
      (.bdyPtOfReal <| -(3 * i + x) / (2 * p + 3 * n))
      (.bdyPtOfReal <| -(3 * i + 3 - x) / (2 * p + 3 * n))

abbrev OrientableRepr (p n : ℕ) := Quot (Surface.OrientableRel p n)

abbrev NonOrientableRepr (p n : ℕ) := Quot (Surface.NonOrientableRel p n)

end Surface

open Set

/-- A 3-dimensional handlebody of genus `g`. -/
def handlebody (g : ℕ) : Set (ℝ × ℝ × ℝ) :=
  Icc 0 1 ×ˢ (Icc 0 (2 * (g : ℝ) + 1) ×ˢ Icc 0 3 \ ⋃ i : Fin g, Ioo (2 * (i : ℝ) + 1) (2 * i + 2) ×ˢ Ioo 1 2)

@[eval_problem]
def frontierHandlebodyHomeomorphOrientableRepr (g : ℕ) (hg : g ≠ 0) :
    frontier (handlebody g) ≃ₜ Surface.OrientableRepr g 0 := by
  sorry

@[eval_problem]
def frontierHandlebodyHomeomorphSphere :
    frontier (handlebody 0) ≃ₜ Metric.sphere (0 : EuclideanSpace ℝ (Fin 3)) 1 := by
  sorry

@[eval_problem]
def frontierHandlebodyHomeomorphAddCircleProd :
    frontier (handlebody 1) ≃ₜ AddCircle (1 : ℝ) × AddCircle (1 : ℝ) := by
  sorry

end LeanEval.Topology
