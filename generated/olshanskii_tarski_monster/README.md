# `olshanskii_tarski_monster`

Ol'shanskii's Tarski monster group existence theorem

- Problem ID: `olshanskii_tarski_monster`
- Group: `formalization-evaluation`
- Status: `draft`
- Visible: yes
- Statement Revision: 1
- Tags: none
- Submitter: Edward Lockhart
- Notes: For every prime p > 10^75, there exists an infinite group G whose every proper
nontrivial subgroup is cyclic of order p. Stated with zero new definitions on
top of Mathlib (Nat.Prime, Group, Infinite, Subgroup, IsCyclic, Nat.card).

- Source: A. Yu. Ol'shanskii, An infinite group with subgroups of prime orders, Izv. Akad. Nauk SSSR Ser. Mat. 44 (1980), 309–321 (announced 1979); Groups of bounded period with subgroups of prime order, Algebra i Logika 21 (1982), 553–618; Geometry of Defining Relations in Groups, Kluwer (1991).
- Informal solution: Construct G as the direct limit of a graded sequence of group presentations
G_0 -> G_1 -> G_2 -> ... starting from the free group F_2, inductively adding
defining relators of rank i (p-th powers of minimal-length periods together
with relations forcing every non-commuting pair of elements to generate the
whole group). Using Ol'shanskii's geometric graded small-cancellation theory
for van Kampen diagrams (contiguity subdiagrams, A/B/C-cells, and a large
coupled simultaneous induction on the rank i for p > 10^75), one proves that
the direct limit G is infinite, every element has order dividing p, and any
two elements that do not lie in a common cyclic subgroup generate G.


Do not modify `Challenge.lean` or `Solution.lean`. Those files are part of the
trusted benchmark and fixed by the repository.

Write your solution in `Submission.lean` and any additional local modules under
`Submission/`.

Participants may use declarations from the existing Mathlib imports. Broadening
the import header (especially to `import Mathlib`) can change elaboration of the
fixed statement; any added import must leave `lake build Solution` green. Helper
code not available through compatible imports must be inlined into the workspace.

Multi-file submissions are allowed through `Submission.lean` and additional local
modules under `Submission/`.

`lake test` runs comparator for this problem. The command expects a comparator
binary in `PATH`, or in the `COMPARATOR_BIN` environment variable.
