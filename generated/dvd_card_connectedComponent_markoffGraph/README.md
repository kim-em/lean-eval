# `dvd_card_connectedComponent_markoffGraph`

Chen theorem for Markoff graphs

- Problem ID: `dvd_card_connectedComponent_markoffGraph`
- Test Problem: no
- Author: Kim Morrison
- Notes: For prime p > 3, every connected component of the nonzero Markoff graph over ZMod p has cardinality divisible by p.
- Source: https://link.springer.com/article/10.1007/s00222-025-01346-9
- Informal solution: Exploit the Vieta involution symmetries of the Markoff graph over F_p and show each connected component has size divisible by p.

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
