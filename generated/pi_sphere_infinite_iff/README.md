# `pi_sphere_infinite_iff`

Serre finiteness for homotopy groups of spheres

- Problem ID: `pi_sphere_infinite_iff`
- Test Problem: no
- Submitter: Vasily Ilin
- Notes: A two-way characterization of infinitude: pi_k(S^n) is infinite exactly at k = n and, for even n, at k = 2n-1 (phrased as k + 1 = 2*n to avoid truncated subtraction). The forward direction packages all of Serre's finiteness statements; the backward direction requires exhibiting infinitely many homotopy classes, i.e. degree theory for k = n and a Hopf-invariant or Whitehead-product argument for k = 2n-1 with n even. Quantifying over all k means no finiteness case can be dodged. The hypothesis 1 <= n is necessary: at n = k = 0 the right-hand side holds but pi_0(S^0) is a two-element set. Explicit basepoints follow LeanEval.Topology.HomotopyGroups.
- Source: J.-P. Serre, 'Homologie singuliere des espaces fibres. Applications', Ann. of Math. 54 (1951), 425-505; J.-P. Serre, 'Groupes d'homotopie et classes de groupes abeliens', Ann. of Math. 58 (1953), 258-294. See also A. Hatcher, 'Spectral Sequences in Algebraic Topology', Theorem 1.21.
- Informal solution: Serre class theory applied to the spectral sequences of the path-loop fibrations and Eilenberg-MacLane spaces shows that pi_k(S^n) is finitely generated, and that rationally pi_k(S^n) tensor Q is Q for k = n, and additionally Q for k = 2n-1 when n is even, and 0 otherwise; this gives every finiteness claim. For the infinitude: the degree homomorphism shows pi_n(S^n) surjects onto Z, and for even n the Hopf invariant (equivalently the Whitehead product [iota, iota]) provides an element of infinite order in pi_{2n-1}(S^n).

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
