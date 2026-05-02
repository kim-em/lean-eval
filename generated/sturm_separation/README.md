# `sturm_separation`

Sturm separation theorem

- Problem ID: `sturm_separation`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Between consecutive zeros of one solution of a second-order linear homogeneous ODE, any linearly independent solution has exactly one zero.
- Source: C. Sturm, Mémoire sur les équations différentielles linéaires du second ordre, 1836.
- Informal solution: On (a, b), y_1 has constant sign and never vanishes. The Wronskian W = y_1 y_2' - y_2 y_1' satisfies W' = -p W (Liouville), so W has constant sign on J. Hence (y_2 / y_1)' = -W / y_1^2 has constant sign and y_2 / y_1 is strictly monotone on (a, b). The Wronskian also forces y_2(a), y_2(b) ≠ 0 (else W(a) or W(b) would vanish, contradicting nonvanishing of W). If y_2 had no zero in (a, b), continuity gives sign(y_2(a)) = sign(y_2(b)); then y_2 / y_1 tends to the same infinite sign at both endpoints, contradicting strict monotonicity. Thus y_2 has a zero in (a, b). Uniqueness follows because a strictly monotone function can cross 0 at most once.

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
