# `exists_chiral_knot`

Existence of a chiral oriented knot

- Problem ID: `exists_chiral_knot`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Challenge problem of the knot-theory benchmark. Asks for an oriented smooth knot whose image is not ambient-isotopic to its mirror image (under reflection through the xy-plane), using the benchmark's orientation-sensitive notion of isotopy induced by the parametrization. The model must construct an ambient-isotopy invariant that takes different values on a knot and its mirror -- the knot determinant and Alexander polynomial alone do not suffice, since the figure-eight is amphichiral in the usual unoriented sense.
- Source: Classical; see https://en.wikipedia.org/wiki/Chirality_(mathematics) and https://en.wikipedia.org/wiki/Trefoil_knot.
- Informal solution: Take K = right-handed trefoil. Construct the knot signature sigma(K) from a Seifert matrix V as the signature of V + V^T, and verify that sigma is an ambient-isotopy invariant of knots that negates under mirror reflection. Compute sigma(right trefoil) = -2, so sigma(K) != sigma(mirror K) and K is chiral. (Alternatively, use the Jones polynomial V_K(t) = -t^{-4} + t^{-3} + t^{-1}, which is not symmetric under t <-> t^{-1}.)

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
