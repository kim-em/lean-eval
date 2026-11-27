import TauCeti.Analysis.PDE.Spectrum.Mixed.MinMax
import EvalTools.Markers

/-!
# Euclidean triangles have no hot spots

We formalise the hot spots theorem for triangles of C. Judge and S. Mondal, *Euclidean triangles
have no hot spots*, Ann. of Math. 191 (1) (2020), 167–211,
https://doi.org/10.4007/annals.2020.191.1.3, with *Erratum: Euclidean triangles have no hot
spots*, Ann. of Math. 195 (1) (2022), 337–362, https://doi.org/10.4007/annals.2022.195.1.5
(arXiv:1802.01800).

**Theorem.** Let `T` be a Euclidean triangle and `u` a second Neumann eigenfunction of `T`. Then
the maximum and the minimum of `u` over the closed triangle are attained only on the boundary of
`T`. (The 'hot spots' conjecture of J. Rauch for triangles in the plane.)

## Conventions

* A triangle is `t : Affine.Triangle ℝ (EuclideanSpace ℝ (Fin 2))`, three affinely independent
  points of the plane. The closed triangle is the convex hull of its vertices, and the open
  triangle `T` is its interior, as an element of `Opens`.
* The second Neumann eigenvalue is Tau Ceti's
  `TauCeti.PDE.mixedEigenvalue volume T ∅ (fun _ ↦ 1) 0 0 1`: the eigenvalues of `-Δ` with no
  Dirichlet part (`Γ = ∅`), counted from `0` with multiplicity by the Courant–Fischer min–max
  principle. On a triangle (a bounded connected Lipschitz domain) the eigenvalue of index `0` is
  `0`, with the constants as its only eigenfunctions, so the eigenvalue of index `1` is the least
  positive Neumann eigenvalue, the paper's `μ₂`.
* A second Neumann eigenfunction is a nonzero `u ∈ H¹(T)` (`TauCeti.W1p volume T 2`) with
  `∫_T ∇u · ∇v = μ₂ ∫_T u v` for every `v ∈ H¹(T)`: the weak form of `Δu = μ₂ u` in `T` with
  `∂u/∂n = 0` on `∂T`.
* `u` is an element of `L²(T)`, defined only almost everywhere. The extremum condition is stated
  for every function `f` continuous on the closed triangle that agrees with `u` almost everywhere
  on `T`. Such an `f` exists (by elliptic regularity and the corner analysis at the vertices) and
  is unique, since `T` is dense in the closed triangle.
-/

open MeasureTheory Set TopologicalSpace
open scoped InnerProductSpace

noncomputable section

namespace JudgeMondal

open TauCeti

/-- The closed triangle with vertices `t.points`: the convex hull of the three vertices. -/
def closedTriangle (t : Affine.Triangle ℝ (EuclideanSpace ℝ (Fin 2))) :
    Set (EuclideanSpace ℝ (Fin 2)) :=
  convexHull ℝ (range t.points)

/-- The open triangle with vertices `t.points`: the interior of the closed triangle. -/
def openTriangle (t : Affine.Triangle ℝ (EuclideanSpace ℝ (Fin 2))) :
    Opens (EuclideanSpace ℝ (Fin 2)) :=
  ⟨interior (closedTriangle t), isOpen_interior⟩

/-- **Judge–Mondal: Euclidean triangles have no hot spots.** Let `T` be a Euclidean triangle,
`μ₂` its second Neumann eigenvalue, and `u ∈ H¹(T)` a nonzero weak solution of `Δu = μ₂ u` with
the Neumann condition. If `f` is continuous on the closed triangle and agrees with `u` almost
everywhere on `T`, then every point of the closed triangle at which `f` attains its maximum or
its minimum over the closed triangle lies on the boundary of `T`. -/
@[eval_problem]
theorem triangle_no_hot_spots (t : Affine.Triangle ℝ (EuclideanSpace ℝ (Fin 2)))
    (u : W1p volume (openTriangle t) 2) (hu : u ≠ 0)
    (heig : ∀ v : W1p volume (openTriangle t) 2,
      ⟪W1p.gradient u, W1p.gradient v⟫_ℝ =
        PDE.mixedEigenvalue volume (openTriangle t) ∅ (fun _ ↦ 1) 0 0 1 *
          ⟪W1p.value u, W1p.value v⟫_ℝ)
    (f : EuclideanSpace ℝ (Fin 2) → ℝ) (hf : ContinuousOn f (closedTriangle t))
    (hfu : (W1p.value u : EuclideanSpace ℝ (Fin 2) → ℝ) =ᵐ[volume.restrict (openTriangle t)] f)
    (x : EuclideanSpace ℝ (Fin 2)) (hx : x ∈ closedTriangle t)
    (hext : IsMaxOn f (closedTriangle t) x ∨ IsMinOn f (closedTriangle t) x) :
    x ∈ frontier (closedTriangle t) := by
  sorry

end JudgeMondal
