import ChallengeDeps

open LeanEval.ComplexAnalysis
open scoped Manifold

theorem unbounded_denominators (Γ : Subgroup (Matrix.SpecialLinearGroup (Fin 2) ℤ)) [Γ.FiniteIndex]
    (k : ℤ) (f : SlashInvariantForm Γ k) (mdiff : MDiff f)
    (bdd : UpperHalfPlane.IsBoundedAtImInfty f)
    (mero : ∀ c : OnePoint ℚ, IsMeromorphicAt (c.map ((↑) : ℚ → ℝ)) f k)
    (int : ∀ n, IsIntegral ℤ (UpperHalfPlane.qExpansion Γ.index.factorial f n)) :
    ∃ N > 0, ∀ γ ∈ CongruenceSubgroup.Gamma N, SlashAction.map k γ ⇑f = f := by
  sorry
