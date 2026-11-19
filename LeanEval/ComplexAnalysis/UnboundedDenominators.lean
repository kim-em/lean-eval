import Mathlib
import EvalTools.Markers

/-!
# Unbounded denominators conjecture

The main theorem (Theorem 1.0.1) in *The Unbounded Denominators Conjecture* by
Frank Calegari, Vesselin Dimitrov, and Yunqing Tang (https://arxiv.org/abs/2109.09040)
states that if `f` is a modular form for some finite index subgroup of SL(2,ℤ) that
is holomorphic on the upper half-plane and at infinity and meromorphic at cusps other
than the infinity, with all Fourier (q-expansion) coefficients at infinity algebraic
integers (see Remark 6.3.1), then `f` is a modular form for some congruence subgroup of SL(2,ℤ).

The proof uses arithmetic holonomy bounds and Nevanlinna theory, which are also central to
the three authors' subsequent work, another LeanEval challenge
https://lean-lang.org/eval/problems/cdt_linearIndependent/.

## More references
* Published paper: https://www.math.uchicago.edu/~fcale/papers/UDC.pdf
* Séminaire Bourbaki by Javier Fresán: http://javier.fresan.perso.math.cnrs.fr/unbounded.pdf
* Vector valued version and Mason's conjecture: https://divizio.perso.math.cnrs.fr/SemDiff/dimitrov.pdf
* https://www.quantamagazine.org/long-sought-math-proof-unlocks-more-mysterious-modular-forms-20230309/
-/

namespace LeanEval.ComplexAnalysis

open scoped Manifold

/-- A slash invariant holomorphic function `f` on the upper half-plane is meromorphic at a cusp
if every slash action that brings the cusp to infinity brings `f` to a function that is O(eⁱᵗᶻ)
for some `t : ℝ` as Im z → ∞. -/
def IsMeromorphicAt (c : OnePoint ℝ) (f : UpperHalfPlane → ℂ) (k : ℤ) : Prop :=
  ∀ g : GL (Fin 2) ℝ, g • OnePoint.infty = c →
    ∃ t : ℝ, SlashAction.map k g f =O[UpperHalfPlane.atImInfty] fun z ↦ (z.1 * t * .I).exp

/-- In the statement we use the fact that if `[SL(2,ℤ) : Γ] = n`, then `n!` is a period of `f`:
in general, if `[G : H] = n` then the `n!`th power of every element of `G` is in `H`.
Meromorphicity is required only at the rational cusps. The congruence level is positive:
`CongruenceSubgroup.Gamma 0` is the trivial subgroup, which would make the conclusion vacuous. -/
@[eval_problem]
theorem unbounded_denominators (Γ : Subgroup (Matrix.SpecialLinearGroup (Fin 2) ℤ)) [Γ.FiniteIndex]
    (k : ℤ) (f : SlashInvariantForm Γ k) (mdiff : MDiff f)
    (bdd : UpperHalfPlane.IsBoundedAtImInfty f)
    (mero : ∀ c : OnePoint ℚ, IsMeromorphicAt (c.map ((↑) : ℚ → ℝ)) f k)
    (int : ∀ n, IsIntegral ℤ (UpperHalfPlane.qExpansion Γ.index.factorial f n)) :
    ∃ N > 0, ∀ γ ∈ CongruenceSubgroup.Gamma N, SlashAction.map k γ ⇑f = f := by
  sorry

end LeanEval.ComplexAnalysis
