# `zelmanov_restricted_burnside`

Zelmanov's solution of the restricted Burnside problem

- Problem ID: `zelmanov_restricted_burnside`
- Group: `formalization-evaluation`
- Status: `draft`
- Visible: yes
- Statement Revision: 1
- Tags: none
- Submitter: Edward Lockhart
- Notes: For all integers m, n >= 1, there exists a uniform upper bound B bounding the
cardinality of every finite m-generated group of exponent dividing n (equivalently,
the universal restricted Burnside quotient B_0(m, n) is finite). Stated with zero
new definitions on top of Mathlib.

- Source: E. I. Zelmanov, Solution of the restricted Burnside problem for groups of odd exponent, Izv. Akad. Nauk SSSR Ser. Mat. 54 (1990), 42–59; Solution of the restricted Burnside problem for 2-groups, Mat. Sb. 182 (1991), 568–592; combined with P. Hall and G. Higman, On the p-length of p-soluble groups and reduction theorems for Burnside's problem, Proc. London Math. Soc. (3) 6 (1956), 1–42.
- Informal solution: By the Hall-Higman reduction (1956) together with the Classification of Finite
Simple Groups (showing there are only finitely many finite simple groups of
exponent dividing n), the problem reduces to finite p-groups of prime-power
exponent n = p^k. Passing to the associated Lie ring L(G) of the lower central
series (or Lazard's p-central series), L(G) is a finitely generated Lie algebra
over F_p satisfying a polynomial identity (from the Magnus-Sanov/Higman-Kreknin
identities) and a linearized Engel condition on Lie commutators. Zelmanov (1990,
1991; simplified in Vaughan-Lee's monograph) proves via Jordan-pair / sandwich-element
methods and local nilpotency of Engel Lie algebras with polynomial identity that
such Lie rings have bounded nilpotency class depending only on m and p^k, which
yields the uniform cardinality bound on Q.


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
