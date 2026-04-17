# `smale_conjecture`

Smale conjecture (Hatcher) in relative parameterized form

- Problem ID: `smale_conjecture`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Hatcher's 1983 theorem that Diff(S3) is homotopy equivalent to O(4), stated in the relative-parameterized-family form (families on a compact manifold-with-boundary X whose boundary already factors through O(4) deform rel boundary to a family fully factoring through O(4)). Mathlib does not yet carry the C-infinity topology on Diffeomorph, which would be needed for the direct homotopy-equivalence formulation.
- Source: A. Hatcher, A proof of the Smale conjecture, Diff(S3) = O(4), Ann. of Math. 117 (1983).
- Informal solution: Hatcher proves Diff(S3) is homotopy equivalent to O(4) by analyzing configurations of 2-spheres in S3 (the bigon criterion) and deducing by induction that every self-diffeomorphism is isotopic to a linear one, with all higher parameterized versions handled by the same incompressible-surface machinery.

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
