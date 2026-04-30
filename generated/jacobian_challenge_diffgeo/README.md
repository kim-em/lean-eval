# `jacobian_challenge_diffgeo`

Jacobian of a compact Riemann surface (Buzzard challenge)

- Problem ID: `jacobian_challenge_diffgeo`
- Test Problem: no
- Submitter: Kevin Buzzard
- Holes (24): `JacobianChallenge.genus` (def), `JacobianChallenge.genus_eq_zero_iff_homeo` (theorem), `JacobianChallenge.Jacobian` (def), `JacobianChallenge.Jacobian.instAddCommGroup` (def), `JacobianChallenge.Jacobian.instTopologicalSpace` (def), `JacobianChallenge.Jacobian.instT2Space` (theorem), `JacobianChallenge.Jacobian.instCompactSpace` (theorem), `JacobianChallenge.Jacobian.instChartedSpace` (def), `JacobianChallenge.Jacobian.instIsManifold` (theorem), `JacobianChallenge.Jacobian.instLieAddGroup` (theorem), `JacobianChallenge.Jacobian.ofCurve` (def), `JacobianChallenge.Jacobian.ofCurve_contMDiff` (theorem), `JacobianChallenge.Jacobian.ofCurve_self` (theorem), `JacobianChallenge.Jacobian.ofCurve_inj` (theorem), `JacobianChallenge.Jacobian.pushforward` (def), `JacobianChallenge.Jacobian.pushforward_contMDiff` (theorem), `JacobianChallenge.Jacobian.pushforward_id_apply` (theorem), `JacobianChallenge.Jacobian.pushforward_comp_apply` (theorem), `JacobianChallenge.Jacobian.pullback` (def), `JacobianChallenge.Jacobian.pullback_contMDiff` (theorem), `JacobianChallenge.Jacobian.pullback_id_apply` (theorem), `JacobianChallenge.Jacobian.pullback_comp_apply` (theorem), `JacobianChallenge.Jacobian.degree` (def), `JacobianChallenge.Jacobian.pushforward_pullback` (theorem)
- Source: https://leanprover.zulipchat.com/#narrow/stream/583336-Autoformalization/topic/Jacobian%20challenge
- Informal solution: Construct J(X) as H^0(X, Omega^1)* / H_1(X, Z), the period lattice quotient; the Abel-Jacobi map sends a point to the linear functional 'integrate from a fixed basepoint to here'. Functoriality and the projection formula come from pushforward and pullback of differential forms.

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
