import ChallengeDeps
import Submission

open LeanEval.Analysis

theorem gleason_theorem_separable {H : Type*} [NormedAddCommGroup H] [InnerProductSpace ℂ H]
      [CompleteSpace H] [TopologicalSpace.SeparableSpace H]
    (hdim : 3 ≤ Module.rank ℂ H)
    (f : SphereFrameFunction H) :
    ∃ ρ : H →L[ℂ] H,
      ContinuousLinearMap.IsPositive ρ ∧
      ∀ x : Metric.sphere (0 : H) 1,
        f.f x = (inner ℂ (x : H) (ρ (x : H))).re := by
  exact Submission.gleason_theorem_separable hdim f
