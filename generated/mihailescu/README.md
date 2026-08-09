# `mihailescu`

Mihăilescu's theorem

- Problem ID: `mihailescu`
- Test Problem: no
- Submitter: Vasily Ilin
- Notes: Mihăilescu's theorem (formerly Catalan's conjecture): if x and y are positive natural numbers, m and n are natural numbers greater than 1, and x^m = y^n + 1, then x = 3, y = 2, m = 2, and n = 3. Writing the equation with addition avoids the truncation semantics of subtraction on natural numbers. Mathlib has infrastructure for cyclotomic fields and units but no proof of Catalan's conjecture.
- Source: P. Mihăilescu, Primary cyclotomic units and a proof of Catalan's conjecture, Journal für die reine und angewandte Mathematik 572 (2004), 167–195, https://doi.org/10.1515/crll.2004.048.
- Informal solution: First, positivity and the equation rule out x = 1 and y = 1, so both bases are greater than 1. Reduce composite exponents to prime divisors. Classical results of Lebesgue and Ko Chao handle the cases where an exponent is 2, leaving distinct odd prime exponents p and q. Cassels's divisibility theorem and Mihăilescu's double-Wieferich criterion sharply constrain a hypothetical solution. Mihăilescu's proof then splits into two cases: when neither exponent is 1 modulo the other, the solution would produce an excess of primary cyclotomic units and a Galois-module and class-group annihilation argument using Thaine's theorem gives a contradiction; the complementary case is excluded using lower bounds for linear forms in logarithms and explicit finite computations. Thus the sole nontrivial consecutive pair is 2^3 = 8 and 3^2 = 9.

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
