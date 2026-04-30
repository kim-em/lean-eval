# `gleason_theorem_separable`

Gleason's theorem (separable Hilbert space)

- Problem ID: `gleason_theorem_separable`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Gleason's theorem for a separable complex Hilbert space H of dimension at least 3, in Gleason's original `frame function on the unit sphere' formulation: any non-negative function on the unit sphere whose values sum to 1 along every Hilbert basis is given by x ↦ re ⟨x, ρ x⟩ for some positive bounded operator ρ. The Lean conclusion does not assert that ρ is trace-class with Tr(ρ) = 1; stating that would require trace-class infrastructure not yet at this Mathlib pin. This side-steps the absence of Schatten 1 / trace-class infrastructure in Mathlib at the time of writing.
- Source: A. M. Gleason, Measures on the closed subspaces of a Hilbert space, J. Math. Mech. 6 (1957), 885-893.
- Informal solution: Reduce to the real 3-dimensional case via restriction to real subspaces of H, where Gleason's continuity argument plus an analysis of regular frame functions on S^2 gives a positive quadratic form. Patch these forms together using rotation-invariance and the assumed basis-sum normalization to obtain a globally defined positive bounded operator ρ on H reproducing the frame function on every unit vector.

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
