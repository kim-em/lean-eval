# `designs_exist`

The existence of designs

- Problem ID: `designs_exist`
- Group: `formalization-evaluation`
- Status: `draft`
- Visible: yes
- Statement Revision: 1
- Tags: none
- Submitter: Junyan Xu
- Holes (6): `LeanEval.Combinatorics.DesignsExist.keevash` (theorem), `LeanEval.Combinatorics.DesignsExist.steiner_triple_asymptotics` (theorem), `LeanEval.Combinatorics.DesignsExist.keevash_resolvable` (theorem), `LeanEval.Combinatorics.DesignsExist.keevash_large_set` (theorem), `LeanEval.Combinatorics.DesignsExist.keevash_complete_resolution` (theorem), `LeanEval.Combinatorics.DesignsExist.keevash_sah_sawhney` (theorem)
- Notes: Keywords: probabilistic method, randomized algebraic constructions, absorption.

Do not modify `Challenge.lean` or `Solution.lean`. Those files are part of the
trusted benchmark and fixed by the repository.

This is a multi-hole problem: the challenge declares multiple `def`s,
`instance`s, and/or `theorem`s as `sorry`. Fill all of them in
`Submission.lean` (under `namespace Submission`) for comparator to accept
your solution.

Participants may use declarations from the existing Mathlib imports. Broadening
the import header (especially to `import Mathlib`) can change elaboration of the
fixed statement; any added import must leave `lake build Solution` green. Helper
code not available through compatible imports must be inlined into the workspace.

`lake test` runs comparator for this problem. The command expects a comparator
binary in `PATH`, or in the `COMPARATOR_BIN` environment variable.
