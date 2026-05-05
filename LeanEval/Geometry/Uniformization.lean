import Mathlib.AlgebraicTopology.FundamentalGroupoid.FundamentalGroup
import Mathlib.Analysis.Complex.Basic
import Mathlib.Analysis.Complex.UpperHalfPlane.Manifold
import Mathlib.Geometry.Manifold.Diffeomorph
import EvalTools.Markers

/-!
# Uniformization theorem for Riemann surfaces

The usual statement of the uniformization theorem says that a simply connected Riemann surface
is isomorphic to either the Riemann sphere, the complex plane, or the open unit disc
[Hubbard, Theorem 1.1.1]. Since we do not have Riemann sphere in mathlib yet, here we instead
formalize the statement of Theorem 1.1.2, which Hubbard shows is stronger than Theorem 1.1.1
using one page of algebraic topology and complex analysis. The statement is:

If a Riemann surface `X` is connected and noncompact and its cohomology satisfies H¹(X,ℝ)=0,
then it is isomorphic either to the complex plane or to the open unit disc.

Since mathlib does not have singular cohomology yet, we write H¹(X,ℝ) as Hom(π₁(X),ℝ),
which as Hubbard remarks is valid for connected topological spaces.
We also replace the open unit disc by the upper half plane, because the latter already
has a Riemann surface structure in mathlib while the former does not.

Hubbard devotes §1.2–1.7 (15 pages) to proving this statement. §1.3 is devoted to Radó's
theorem (Riemann surfaces are second-countable), which is another LeanEval problem
(`LeanEval.Geometry.rado_riemannSurface`). To avoid the overlap, we assume the
Riemann surface is second countable in our statement here.

Reference:
[Hubbard] John Hamal Hubbard, *Teichmüller theory and applications to geometry, topology, and dynamics. Vol. 1*
-/

namespace LeanEval.Geometry

noncomputable abbrev mℂ := modelWithCornersSelf ℂ ℂ

open scoped Manifold ContDiff

@[eval_problem]
theorem uniformization {X : Type*} [TopologicalSpace X] [T2Space X] [ConnectedSpace X]
    [SecondCountableTopology X] [ChartedSpace ℂ X] [IsManifold mℂ 1 X]
    (hX : ¬ CompactSpace X) (x : X) [Subsingleton <| Additive (FundamentalGroup X x) →+ ℝ] :
    Nonempty (X ≃ₘ⟮mℂ, mℂ⟯ ℂ) ∨ Nonempty (X ≃ₘ⟮mℂ, mℂ⟯ UpperHalfPlane) := by
  sorry

end LeanEval.Geometry
