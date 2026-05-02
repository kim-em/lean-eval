# `exists_nonisotopic_knots`

Existence of a non-isotopic pair of oriented knots

- Problem ID: `exists_nonisotopic_knots`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Asks for two oriented smooth knots in R^3 that are not ambient-isotopic. The benchmark uses an orientation-sensitive notion of isotopy induced by the parametrizations. Mathlib has no knot-invariant infrastructure, so the model must construct an isotopy invariant from scratch. Suggested: the Alexander polynomial / knot determinant, or the Fox 3-coloring count, both of which distinguish the unknot from the trefoil.
- Source: Classical; see https://en.wikipedia.org/wiki/Knot_invariant.
- Informal solution: Take K1 = unknot (round circle in the xy-plane) and K2 = right-handed trefoil parametrized as t -> (sin t + 2 sin 2t, cos t - 2 cos 2t, -sin 3t). Construct an ambient-isotopy invariant; the simplest computable choice is the number of Fox 3-colorings of any diagram of K, which counts homomorphisms from the knot group to D_3. The unknot admits 3 such colorings (all monochromatic); the trefoil admits 9. Hence the two knots are not ambient-isotopic.

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
