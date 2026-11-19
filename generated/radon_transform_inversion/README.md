# `radon_transform_inversion`

Radon transform: Fourier-slice diagonalization and pseudo-inversion

- Problem ID: `radon_transform_inversion`
- Group: `formalization-evaluation`
- Status: `archived`
- Visible: yes
- Statement Revision: 1
- Tags: none
- Submitter: Kim Morrison
- Notes: The Fourier slice theorem diagonalizes the Radon transform (1D Fourier of a projection = a 2D-Fourier slice), and the transform has a left inverse on Schwartz functions. Trusted helpers radon, fourier1, fourier2 (non-holes). Mathlib has the 1D/2D Fourier transforms and Schwartz space but no Radon transform, Fourier slice theorem, or filtered back-projection. The pseudo-inverse is stated existentially (the explicit filtered-back-projection form would need the Hilbert transform / Riesz potential). Candidate from §100 of the Knill survey.
- Source: J. Radon (1917); R. N. Bracewell (Fourier slice theorem, 1956). Knill, *Some fundamental theorems in mathematics*, §100.
- Informal solution: Fourier slice theorem: writing the Radon projection R f(p,θ) and taking its 1D Fourier transform in p, interchange integrals (Fubini) and change variables so the line-integral-then-Fourier becomes the 2D Fourier transform of f restricted to the line through the origin at angle θ: `F₁[Rf(·,θ)](k) = F₂[f](k cos θ, k sin θ)`. This diagonalizes R (it becomes a slice/multiplication operator). Pseudo-inversion: the slice identity plus 2D Fourier inversion on Schwartz functions makes R injective on 𝓢, so a left inverse exists; the canonical one is filtered back-projection u ↦ backproject(Hilbert-filter(u)). Mathlib lacks the slice theorem and the filter.

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
