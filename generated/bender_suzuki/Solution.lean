import ChallengeDeps
import Submission

open LeanEval.GroupTheory
open LeanEval.GroupTheory.Defs

theorem bender_suzuki {X : Type*} [Group X] [Finite X] [IsSimpleGroup X]
    (M : Subgroup X) (h : IsStronglyEmbedded M) :
    IsSimpleBenderGroup X := by
  exact Submission.bender_suzuki M h
