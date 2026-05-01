# `glauberman_zStar`

Glauberman's Z* theorem for isolated involutions

- Problem ID: `glauberman_zStar`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: For a finite group G with an isolated involution t (no distinct conjugate of t commutes with t), there is a normal subgroup N ⊴ G of odd order such that every commutator g·t·g⁻¹·t⁻¹ lies in N — i.e., t is central in G/N. The hypothesis is the global form of isolation, equivalent to (but more self-contained than) the standard Sylow-local form. Proof uses modular Brauer character theory.
- Source: G. Glauberman, Central elements in core-free groups, J. Algebra 4 (1966).
- Informal solution: Take N = O(G), the largest normal subgroup of odd order. By Glauberman's modular character argument, isolation of t in C_G(t) implies t commutes with every element of G modulo O(G). The core of the proof is the analysis of the principal 2-block of G via Brauer characters and the Z*-style fusion theorem.

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
