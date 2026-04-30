# `jacobian_challenge_alggeo`

Jacobian of a smooth proper curve (Merten challenge)

- Problem ID: `jacobian_challenge_alggeo`
- Test Problem: no
- Submitter: Christian Merten
- Holes (9): `AlgebraicGeometry.JacobianChallenge.genus` (def), `AlgebraicGeometry.JacobianChallenge.Jacobian` (def), `AlgebraicGeometry.JacobianChallenge.Jacobian.instGrpObj` (def), `AlgebraicGeometry.JacobianChallenge.Jacobian.smoothOfRelativeDimension_genus` (theorem), `AlgebraicGeometry.JacobianChallenge.Jacobian.instIsProper` (theorem), `AlgebraicGeometry.JacobianChallenge.Jacobian.instGeometricallyIrreducible` (theorem), `AlgebraicGeometry.JacobianChallenge.Jacobian.ofCurve` (def), `AlgebraicGeometry.JacobianChallenge.Jacobian.comp_ofCurve` (theorem), `AlgebraicGeometry.JacobianChallenge.Jacobian.exists_unique_ofCurve_comp` (theorem)
- Source: https://leanprover.zulipchat.com/#narrow/stream/583336-Autoformalization/topic/Jacobian%20challenge/near/587802685
- Informal solution: Build the Albanese variety of C as the universal abelian variety receiving a pointed map from C; Weil's construction of the Jacobian of a curve makes this concrete via Pic^0(C). The universal property is the no-cheating clamp.

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
