import ChallengeDeps
import Submission

open LeanEval.KnotTheory

theorem exists_nonisotopic_link : ∃ L₁ L₂ : TwoLink, ¬ L₁.Isotopic L₂ := by
  exact Submission.exists_nonisotopic_link
