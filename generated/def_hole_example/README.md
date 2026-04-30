# `def_hole_example`

def-hole minimal example

- Problem ID: `def_hole_example`
- Test Problem: yes
- Submitter: Kim Morrison
- Holes (2): `foo` (def), `foo_def` (theorem)
- Notes: Minimal example exercising def + theorem holes through the comparator def-hole pipeline.

Do not modify `Challenge.lean` or `Solution.lean`. Those files are part of the
trusted benchmark and fixed by the repository.

This is a multi-hole problem: the challenge declares multiple `def`s,
`instance`s, and/or `theorem`s as `sorry`. Fill all of them in
`Submission.lean` (under `namespace Submission`) for comparator to accept
your solution.

Participants may use Mathlib freely. Any helper code not already available in
Mathlib must be inlined into the submission workspace.

`lake test` runs comparator for this problem. The command expects a comparator
binary in `PATH`, or in the `COMPARATOR_BIN` environment variable.
