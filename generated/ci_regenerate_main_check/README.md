# `ci_regenerate_main_check`

CI regenerate-main check

- Problem ID: `ci_regenerate_main_check`
- Test Problem: yes
- Submitter: Kim Morrison
- Notes: Internal trivial problem used to exercise the regenerate-main workflow end-to-end.
- Source: Internal CI check.
- Informal solution: True is true.

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
