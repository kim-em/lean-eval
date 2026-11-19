import Mathlib

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



end LeanEval.ComplexAnalysis
