# `five_transitive_card_classification`

Possible orders of 5-transitive finite permutation groups

- Problem ID: `five_transitive_card_classification`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: If a finite group acts faithfully and 5-transitively on a set X with |X| ≥ 5, then |G| is one of n!, n!/2 (only when n ≥ 7), 95040 (= |M₁₂|), or 244823040 (= |M₂₄|). The 5 ≤ |X| hypothesis prevents the 5-transitivity condition from being vacuously satisfied (otherwise small groups like C₃ on Fin 3 would qualify). Classification is folklore via CFSG; no CFSG-free proof is known.
- Source: Folklore via CFSG; classical work of Mathieu, Jordan; modern accounts in P. Cameron, Permutation Groups (1999).
- Informal solution: By CFSG, the only finite 2-transitive groups are explicitly classified. Restricting to 5-transitive: the symmetric group Sₙ is k-transitive for all k ≤ n; the alternating group Aₙ is k-transitive for k ≤ n − 2 (so 5-transitive for n ≥ 7); among the Mathieu groups, M₁₂ is sharply 5-transitive on 12 points and M₂₄ is 5-transitive on 24 points. M₁₁ and M₂₃ are only 4-transitive and so do not appear. No other finite simple group has a 5-transitive permutation representation.

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
