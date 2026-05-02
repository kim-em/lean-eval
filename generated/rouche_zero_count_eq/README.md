# `rouche_zero_count_eq`

Rouche theorem via zero counting

- Problem ID: `rouche_zero_count_eq`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Phrases Rouché's theorem as equality of multiplicity-counted zero counts for f and f + g on the closed disk of radius R.
- Source: Classical theorem in complex analysis.
- Informal solution: If |g| < |f| on the boundary circle, then f and f + g have the same number of zeros inside, counted with multiplicity.

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
