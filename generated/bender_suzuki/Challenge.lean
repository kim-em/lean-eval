import ChallengeDeps

open LeanEval.GroupTheory
open LeanEval.GroupTheory.Defs

theorem bender_suzuki {X : Type*} [Group X] [Finite X] [IsSimpleGroup X]
    (M : Subgroup X) (h : IsStronglyEmbedded M) :
    IsSimpleBenderGroup X := by
  sorry
