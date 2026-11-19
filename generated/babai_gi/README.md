# `babai_gi`

Quasipolynomial graph isomorphism assuming Schreier's hypothesis

- Problem ID: `babai_gi`
- Group: `formalization-evaluation`
- Status: `draft`
- Visible: yes
- Statement Revision: 1
- Tags: none
- Submitter: Timothy Y. Chow
- Notes: Babai proved that graph isomorphism is decidable in quasipolynomial time.
The proof relies on Schreier's hypothesis, whose only known proof at the
time of this writing relies on the classification of finite simple
groups (CFSG). Therefore, here we assert only the weaker statement that
if Schreier's hypothesis holds, then graph isomorphism can be decided in
quasipolynomial time. This sidesteps the need to prove CFSG.

Schreier's hypothesis states that every finite simple group has solvable
outer automorphism group. Note that Babai's proof ostensibly depends on
Cameron’s classification of large primitive permutation groups, which also
depends on the CFSG, but he explains in Section 13 how the dependence on
Cameron's result can be avoided.

- Source: L. Babai, Graph Isomorphism in Quasipolynomial Time, arXiv:1512.03547v2 (19 January 2016), Corollary 1.1.2 and Section 13.1.

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
