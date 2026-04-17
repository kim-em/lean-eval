# `g2_irrep_tensor_square_decomp`

Tensor square decomposition of a 64-dim irreducible g₂-representation

- Problem ID: `g2_irrep_tensor_square_decomp`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: g₂ is the smallest exceptional Lie algebra, defined here by the Serre construction (Mathlib's `LieAlgebra.g₂`). The relevant irreducible representation has highest weight ω₁ + ω₂ (the sum of the two fundamental weights), dimension 64; its tensor square decomposes into 14 isomorphism classes of irreducible Lie submodules. The U(g)-module structure on V ⊗ V used in the statement comes from lifting the Lie action via the universal enveloping algebra.
- Source: Classical: representation theory of the exceptional Lie algebra g₂.
- Informal solution: Construct V as the irreducible 64-dim representation V(ω₁+ω₂). Decomposition (LiE-verified): V⊗V = V(0,0) + V(1,0) + 2V(0,1) + 2V(2,0) + 2V(1,1) + 2V(0,2) + 3V(3,0) + 3V(2,1) + V(1,2) + V(0,3) + 2V(4,0) + 2V(3,1) + V(2,2) + V(5,0). The 14 distinct highest weights give 14 isotypic components.

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
