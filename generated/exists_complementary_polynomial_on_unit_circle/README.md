# `exists_complementary_polynomial_on_unit_circle`

Complementary polynomial on the unit circle

- Problem ID: `exists_complementary_polynomial_on_unit_circle`
- Test Problem: no
- Author: Kim Morrison
- Notes: If a complex polynomial has modulus at most 1 on the unit circle, then there is a same-degree complementary polynomial whose squared moduli add to 1 on the circle.
- Source: https://link.springer.com/article/10.1007/s00220-025-05302-9
- Informal solution: Construct a polynomial Q so that |P(z)|^2 + |Q(z)|^2 = 1 for all z on the unit circle.

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
