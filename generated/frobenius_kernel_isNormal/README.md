# `frobenius_kernel_isNormal`

Frobenius's theorem: the Frobenius kernel is normal

- Problem ID: `frobenius_kernel_isNormal`
- Test Problem: no
- Submitter: Kim Morrison
- Notes: For a Frobenius group G acting transitively and faithfully on X with |X| ≥ 2, non-trivial point stabilisers, and the Frobenius condition (no non-identity element fixes more than one point), the set {1} ∪ {g | g fixes no point} is a normal subgroup. The only known proof uses Frobenius's induction-of-characters argument; no purely group-theoretic proof has been found in over a century.
- Source: G. Frobenius, Über auflösbare Gruppen IV, Sitzungsber. Akad. Wiss. Berlin (1901).
- Informal solution: Let H = stabilizer(x₀). Construct a class function θ on H of the form (1_H minus restriction of certain induced characters), and apply Frobenius reciprocity to lift θ to a generalised character of G whose kernel is exactly the Frobenius kernel K. The fact that the lift remains a virtual character (i.e. integer-valued combination of irreducibles) is exactly the content; that K is then a subgroup follows from K being a kernel.

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
