import Mathlib
import EvalTools.Markers

namespace LeanEval
namespace RepresentationTheory

/-!
Brauer's theorem on character values.

For a finite group `G` of exponent `n`, every value of every complex
character of `G` lies in (the image of) the cyclotomic field `ℚ(ζₙ)`.
Concretely: there is a ring embedding `φ : ℚ(ζₙ) →+* ℂ` whose range
contains `tr ρ(g)` for every finite-dimensional complex representation
`ρ` of `G` and every `g ∈ G`.

This is a consequence of Brauer's induction theorem (every character is a
ℤ-combination of characters induced from elementary subgroups, whose values
are visibly cyclotomic).

The full Brauer "splitting field" theorem says more — that `ℚ(ζₙ)` is in fact
a *splitting field* for the group algebra, i.e. every irreducible complex
representation admits a `ℚ(ζₙ)`-form. The character-value statement below
is implied by the splitting-field statement and is the part most cleanly
expressible in Mathlib's current API; the full splitting-field statement
would additionally require scalar-extension scaffolding around
`CyclotomicField n ℚ → ℂ`.
-/

@[eval_problem]
theorem brauer_character_in_cyclotomic
    (G : Type) [Group G] [Fintype G] :
    ∃ φ : CyclotomicField (Monoid.exponent G) ℚ →+* ℂ,
      ∀ (V : Type) (_ : AddCommGroup V) (_ : Module ℂ V) (_ : FiniteDimensional ℂ V)
        (ρ : Representation ℂ G V) (g : G),
        LinearMap.trace ℂ V (ρ g) ∈ φ.range := by
  sorry

end RepresentationTheory
end LeanEval
