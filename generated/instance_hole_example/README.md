# `instance_hole_example`

instance-hole minimal example

- Problem ID: `instance_hole_example`
- Test Problem: yes
- Submitter: Kim Morrison
- Holes (2): `WidgetCarrier` (def), `instInhabitedWidget` (def)
- Notes: Minimal example exercising instance + theorem holes; instances must be named so the comparator can address them.

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
