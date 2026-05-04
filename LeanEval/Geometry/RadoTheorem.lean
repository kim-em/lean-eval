import Mathlib.Geometry.Manifold.IsManifold.Basic
import EvalTools.Markers

/-!
# Radó's theorem on Riemann surfaces

Radó's theorem, proved by Tibor Radó (1925), states that every connected Riemann surface
is second-countable (has a countable base for its topology).
A prerequisite to the uniformization theorem in John Hamal Hubbard,
*Teichmüller theory and applications to geometry, topology, and dynamics. Vol. 1* (§1.3).

See also https://en.wikipedia.org/wiki/Rad%C3%B3%27s_theorem_(Riemann_surfaces)
-/

namespace LeanEval.Geometry

@[eval_problem]
theorem rado_riemannSurface {X : Type*} [TopologicalSpace X] [T2Space X] [ConnectedSpace X]
    [ChartedSpace ℂ X] [IsManifold (modelWithCornersSelf ℂ ℂ) 1 X] :
    SecondCountableTopology X := by
  sorry

end LeanEval.Geometry
