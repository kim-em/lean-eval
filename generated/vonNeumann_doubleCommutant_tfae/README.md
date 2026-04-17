# `vonNeumann_doubleCommutant_tfae`

von Neumann double commutant theorem

- Problem ID: `vonNeumann_doubleCommutant_tfae`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: The classical double commutant theorem: for a unital *-subalgebra of bounded operators on a complex Hilbert space, equality with the double commutant is equivalent to closedness in the weak operator topology and to closedness in the strong operator topology. WOT and SOT live on Mathlib's irreducible type copies of H →L[ℂ] H (`ContinuousLinearMapWOT` and `PointwiseConvergenceCLM`), so each closure condition is phrased on the image of the carrier under the canonical inclusion.
- Source: J. von Neumann, Zur Algebra der Funktionaloperationen und Theorie der normalen Operatoren, Math. Ann. 102 (1930), 370-427.
- Informal solution: One direction: centralizers are WOT-closed, so any set equal to its double commutant is WOT-closed; norm topology refines WOT refines SOT for continuity of evaluation, and closedness under a finer convex topology is implied by closedness under a coarser one (via Hahn-Banach for convex sets). Hard direction: given a unital *-subalgebra S that is SOT-closed, for any T in S'' and any finite family of vectors use the amplification S ⊗ 1_n acting diagonally on H^n together with the projection onto the closure of (S ⊗ 1_n) applied to the vector to produce a net in S converging SOT to T.

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
