import ChallengeDeps
import Submission

open LeanEval.Geometry.EquilateralTriangulation

theorem bishop_rempe {X : Type*} [TopologicalSpace X] [T2Space X] [ConnectedSpace X]
    [SecondCountableTopology X] [ChartedSpace ℂ X] [IsManifold mℂ 1 X] (h : ¬ CompactSpace X) :
    let S := Metric.sphere (0 : EuclideanSpace ℝ (Fin 3)) 1
    ∃ (_ : ChartedSpace ℂ S) (_ : IsManifold mℂ 1 S) (f : X → S) (s : Set S),
      ContMDiff mℂ mℂ 1 f ∧ IsBranchedCovering f ∧ IsCoveringMapOn f sᶜ ∧ s.ncard = 3 := by
  exact Submission.bishop_rempe h
