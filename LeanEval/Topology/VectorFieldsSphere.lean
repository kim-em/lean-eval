import Mathlib
import EvalTools.Markers

/-!
# Maximal number of linearly independent vector fields on a sphere

The LeanEval problem https://lean-lang.org/eval/problems/hSpace_sphere_iff/, which states that
𝕊ⁿ is an H-space iff n=0,1,3,7, has been solved on September 24, 2026.

It is closely connected to the statement that 𝕊ⁿ is parallelizable (admits `n` pointwise
linearly independent smooth vector fields) iff n=0,1,3,7.

In this file we add the challenge to compute the maximal number of pointwise linearly independent
continuous vector fields on 𝕊ⁿ, which is given by the Radon–Hurwitz number.

This might serve as a good test for reusability of topological K-theory and Adams operations API
likely present in the H-space development. The construction of enough vector fields further
relies on Clifford algebras.

## References
* Adams, J. F. (1962). "Vector Fields on Spheres". Annals of Mathematics 75 (3): 603–632. doi:10.2307/1970213.
* https://en.wikipedia.org/wiki/Vector_fields_on_spheres
-/

namespace LeanEval.Topology.VectorFieldsSphere

/-- The maximal number of pointwise linearly independent continuous vector fields on 𝕊ⁿ⁻¹.
Vector fields are formalized as functions from 𝕊ⁿ⁻¹ to ℝⁿ that lie in the tangent space
(i.e. orthogonal to `x`) at every point `x : 𝕊ⁿ⁻¹`.  Literature often includes nowhere-zero
as an adjective, but this is implied by everywhere linear independence. -/
noncomputable def maxNumVecFieldsSphere (n : ℕ) : ℕ :=
  let 𝔼 (n : ℕ) := EuclideanSpace ℝ (Fin n)
  sSup {k : ℕ | ∃ v : Fin k → C(Metric.sphere (0 : 𝔼 n) 1, 𝔼 n),
    ∀ x, LinearIndependent ℝ (v · x) ∧ ∀ i, inner ℝ (v i x) x = 0}

/-- The Radon–Hurwitz number ρ(n) is defined to be 2ᶜ + 8d
when one writes n = (2a+1)2⁴ᵈ⁺ᶜ with 0 ≤ c < 4. -/
noncomputable def radonHurwitz (n : ℕ) : ℕ :=
  2 ^ (n.factorization 2 % 4) + 8 * (n.factorization 2 / 4)

/-- The maximal number of pointwise linearly independent continuous vector fields on 𝕊ⁿ⁻¹
is ρ(n) - 1. -/
@[eval_problem]
theorem maxNumVecFieldsSphere_eq_radonHurwitz_sub_one (n : ℕ+) :
    maxNumVecFieldsSphere n = radonHurwitz n - 1 := by
  sorry

end LeanEval.Topology.VectorFieldsSphere
