# `exists_nonisotopic_link`

Existence of a non-isotopic pair of oriented two-component links

- Problem ID: `exists_nonisotopic_link`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: Warmup for the knot-theory benchmark. Asks for two oriented smooth two-component links in R^3 that are not ambient-isotopic. The benchmark uses an orientation-sensitive notion of isotopy induced by the parametrizations, so the Gauss linking integral is a natural real-valued invariant distinguishing the unlink (lk = 0) from the Hopf link (lk = +/- 1, depending on orientation choice).
- Source: Classical; see https://en.wikipedia.org/wiki/Linking_number.
- Informal solution: Take L1 = unlink (two unit circles in parallel planes) and L2 = Hopf link, with explicit orientations induced by the parametrizations. Define lk(K, L) by the Gauss double integral (1/4 pi) int int <K(s) - L(t), K'(s) x L'(t)> / |K(s) - L(t)|^3 ds dt. Prove lk is invariant under ambient isotopy of oriented links by exhibiting it as the integral of a closed 2-form on R^3 minus the origin pulled back along (K, L), so Stokes-style arguments show invariance. Compute lk(unlink) = 0 and choose the Hopf-link orientations so that lk(Hopf) = 1. Conclude L1 and L2 are not ambient-isotopic.

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
