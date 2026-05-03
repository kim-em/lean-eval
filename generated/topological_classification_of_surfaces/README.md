# `topological_classification_of_surfaces`

Topological classification of surfaces

- Problem ID: `topological_classification_of_surfaces`
- Test Problem: no
- Submitter: Junyan Xu
- Notes: A compact connected surface with boundary is homeomorphic to one of the representative surfaces that we formalize.
- Source: Jean Gallier & Dianna Xu, *A Guide to the Classification Theorem for Compact Surfaces*, https://www.cis.upenn.edu/~jean/surfclassif-root.pdf
- Informal solution: Show surfaces are triangulable and therefore homeomorphic to cell complexes, and show each cell complex is equivalent to one in normal form.

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
