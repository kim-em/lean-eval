# `e8_irrep_tensor_square_decomp`

Tensor square decomposition of a 779247-dim irreducible e₈-representation

- Problem ID: `e8_irrep_tensor_square_decomp`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: e₈ is the largest exceptional Lie algebra (dim 248), defined here by the Serre construction (Mathlib's `LieAlgebra.e₈`). The relevant irreducible representation has highest weight ω₁ + ω₈ (the sum of the first and last fundamental weights, in Bourbaki labelling), dimension 779247; its tensor square decomposes into 40 isomorphism classes of irreducible Lie submodules. The U(g)-module structure on V ⊗ V used in the statement comes from lifting the Lie action via the universal enveloping algebra.
- Source: Classical: representation theory of the exceptional Lie algebra e₈.
- Informal solution: Construct V as V(ω₁+ω₈), the unique 779247-dim irrep of e₈. Tensor square (LiE-verified) has 40 distinct simple summand isomorphism classes (155 components with multiplicity), with the smallest being the trivial 1-dim, the 248-dim adjoint (mult 2), the 3875-dim V(ω₁), and so on up to the 85,424,220,000-dim summand.

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
