import Mathlib
import Submission

theorem rado_riemannSurface {X : Type*} [TopologicalSpace X] [T2Space X] [ConnectedSpace X]
    [ChartedSpace ℂ X] [IsManifold (modelWithCornersSelf ℂ ℂ) 1 X] :
    SecondCountableTopology X := by
  exact Submission.rado_riemannSurface
