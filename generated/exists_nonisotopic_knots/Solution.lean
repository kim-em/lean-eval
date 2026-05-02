import ChallengeDeps
import Submission

open LeanEval.KnotTheory

theorem exists_nonisotopic_knots : ∃ K₁ K₂ : Knot, ¬ K₁.Isotopic K₂ := by
  exact Submission.exists_nonisotopic_knots
