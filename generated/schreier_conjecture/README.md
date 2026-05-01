# `schreier_conjecture`

Schreier's conjecture: outer automorphism group of a finite simple group is solvable

- Problem ID: `schreier_conjecture`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: For every finite non-abelian simple group S, Out(S) := Aut(S)/Inn(S) is solvable. The statement requires the normality of Inn(S) ⊴ Aut(S), which is supplied by a local instance with a one-line proof (the conjugate of conj(s) by α equals conj(α(s))). Verified case-by-case via CFSG; no CFSG-free proof is known.
- Source: O. Schreier, Über die Erweiterung von Gruppen II, Abh. Math. Sem. Univ. Hamburg 4 (1926); CFSG, completed c. 2004.
- Informal solution: Use the classification of finite simple groups. For each family — alternating Aₙ, classical Lie type, exceptional Lie type, sporadic — inspect the known Out(S) and verify it is solvable. For Aₙ (n ≥ 5, n ≠ 6), Out = ℤ/2; for A₆, Out = (ℤ/2)²; for groups of Lie type, Out is built from diagonal, field, and graph automorphisms (each step solvable); for sporadics, Out is trivial or ℤ/2.

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
