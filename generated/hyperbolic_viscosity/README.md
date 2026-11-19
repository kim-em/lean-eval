# `hyperbolic_viscosity`

Total variation estimate for hyperbolic systems

- Problem ID: `hyperbolic_viscosity`
- Group: `formalization-evaluation`
- Status: `draft`
- Visible: yes
- Statement Revision: 1
- Tags: none
- Submitter: Joris van Winden
- Source: Bianchini and Bressan, Vanishing viscosity solutions of nonlinear hyperbolic systems. Annals of Mathematics 161 (2005).
- Informal solution: Bianchini and Bressan, Vanishing viscosity solutions of nonlinear hyperbolic systems. Annals of Mathematics 161 (2005).

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
