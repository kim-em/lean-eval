# `mulCayley_connected_iff_closure_eq_top`

Cayley graph connected iff generators generate the group

- Problem ID: `mulCayley_connected_iff_closure_eq_top`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: A foundational result in geometric group theory using the newly defined Cayley graph. Connectivity of the Cayley graph is equivalent to the generating set S generating G as a group.
- Source: A. Cayley, On the theory of groups, as depending on the symbolic equation θ^n = 1, 1878.
- Informal solution: Forward: if connected, any g ∈ G is reached from 1 by a path, which corresponds to a product of generators. Reverse: if S generates, any g is a product of generators, giving a path from 1 to g.

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
