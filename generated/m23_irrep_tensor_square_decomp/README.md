# `m23_irrep_tensor_square_decomp`

Existence of an order-10200960 group with a 22-dim irrep whose tensor square has 4 isotypic components

- Problem ID: `m23_irrep_tensor_square_decomp`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Existential: a finite group G of order 10200960 (= |M₂₃|) with a 22-dimensional irreducible complex representation V whose tensor square (with the diagonal G-action) has exactly 4 isotypic components. Both the MonoidAlgebra ℂ G action on V and on V ⊗[ℂ] V are bound explicitly, with IsScalarTower and an explicit diagonal-action equation g•(v⊗w) = (g•v)⊗(g•w) pinning the V⊗V action. The intended witness is M₂₃ acting on its 22-dim irreducible: V ⊗ V = 1 ⊕ V ⊕ W₂₃₀ ⊕ Λ²V. While the formal statement does not technically require constructing M₂₃ and studying its representation theory, we suspect that in practice it does.
- Source: É. Mathieu, Sur les fonctions cinq fois transitives de 24 quantités, J. Math. Pures Appl. (1873); ATLAS of Finite Groups, M₂₃ character table.
- Informal solution: Realise M₂₃ as a subgroup of S₂₃ (e.g. via the Steiner system S(4,7,23) or as the automorphism group of a ternary Golay code construction). Take V to be the 22-dimensional deleted permutation representation. By 4-transitivity Sym²V is the permutation representation on the 23 choose 2 = 253 unordered pairs, decomposing as 1 + V + W₂₃₀ where W is the unique 230-dimensional irrep; Λ²V is irreducible of dimension 231, giving four pairwise non-isomorphic isotypic components in V⊗V.

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
