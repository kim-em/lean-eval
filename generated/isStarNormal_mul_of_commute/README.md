# `isStarNormal_mul_of_commute`

Product of commuting normal elements is normal

- Problem ID: `isStarNormal_mul_of_commute`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Uses the Fuglede-Putnam-Rosenblum theorem to show all four of a, star a, b, star b pairwise commute, then verifies the normality condition by direct computation.
- Source: B. Fuglede, A commutativity theorem for normal operators, 1950.
- Informal solution: From Commute a b and normality, apply Fuglede-Putnam twice to get Commute (star a) b and Commute (star a) (star b). Then star(ab)·(ab) = b*·a*·a·b = b*·a·a*·b (a normal) = a·b*·b·a* (all commute) = a·b·b*·a* (b normal) = (ab)·star(ab).

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
