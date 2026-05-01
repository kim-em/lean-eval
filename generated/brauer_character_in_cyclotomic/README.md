# `brauer_character_in_cyclotomic`

Character values of finite groups lie in cyclotomic fields

- Problem ID: `brauer_character_in_cyclotomic`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: For a finite group G of exponent n, every value of every complex character of G lies in (the image of) the cyclotomic field ℚ(ζₙ). Stated uniformly for the fixed group G: there is a ring embedding φ : CyclotomicField (Monoid.exponent G) ℚ →+* ℂ whose range contains tr(ρ(g)) for every finite-dimensional complex representation ρ of G and every g. This is a corollary of Brauer's induction theorem; the full splitting-field statement (every irreducible representation has a ℚ(ζₙ)-form) is strictly stronger and requires more scalar-extension scaffolding than mathlib currently exposes cleanly.
- Source: R. Brauer, On the representation of a group of order g in the field of g-th roots of unity, Amer. J. Math. 67 (1945).
- Informal solution: Choose an embedding φ : ℚ(ζₙ) ↪ ℂ once and for all for the fixed group G. Then apply Brauer's induction theorem uniformly: every complex character of G is a ℤ-combination of characters induced from elementary subgroups, and those induced character values lie in φ(ℚ(ζₙ)). Hence for every finite-dimensional complex representation ρ of G and every g ∈ G, tr(ρ(g)) lies in φ.range.

Do not modify `Challenge.lean` or `Solution.lean`. Those files are part of the
trusted benchmark and fixed by the repository.

Write your solution in `Submission.lean` and any additional local modules under
`Submission/`.

Participants may use Mathlib freely. Any helper code not already available in
Mathlib must be inlined into the submission workspace.

Multi-file submissions are allowed through `Submission.lean` and additional local
modules under `Submission/`.

`lake test` runs comparator for this problem. The command expects a comparator
binary in `PATH`, or in the `COMPARATOR_BIN` environment variable.
