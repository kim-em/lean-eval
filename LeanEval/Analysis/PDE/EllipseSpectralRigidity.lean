import TauCeti.Analysis.PDE.Spectrum.Mixed.MinMax
import EvalTools.Markers

/-!
# One can hear the shape of ellipses of small eccentricity

We formalise Theorem 1.1 of H. Hezari and S. Zelditch, *One can hear the shape of ellipses of
small eccentricity*, Ann. of Math. 196 (3) (2022), 1083–1134,
https://doi.org/10.4007/annals.2022.196.3.4 (arXiv:1907.03882).

**Theorem 1.1.** There exists `ε₀ > 0` such that any ellipse with eccentricity less than `ε₀` is
uniquely determined by its Dirichlet (or Neumann) Laplace spectrum, among all smooth domains.

That is: if a bounded planar domain with smooth boundary has the same Dirichlet spectrum, or the
same Neumann spectrum, as an ellipse of eccentricity less than `ε₀`, then it is isometric to that
ellipse.

## Conventions

* The plane is `EuclideanSpace ℝ (Fin 2)` with Lebesgue measure `volume`.
* A *smooth domain* (`IsSmoothDomain`) is a nonempty, connected, bounded open set `Ω` given as
  `{x | ρ x < 0}` by a `C^∞` function `ρ` on the plane whose derivative does not vanish where
  `ρ = 0`. Then `∂Ω = {ρ = 0}` is a smooth curve.
* The ellipse with semi-axes `a ≥ b > 0` is the open region `{x | (x₀ / a)² + (x₁ / b)² < 1}`
  (`ellipse a b`), of eccentricity `√(1 - (b / a)²)` (`eccentricity a b`). Eccentricity `0` is
  the disk.
* The spectra are those of `-Δ`, listed in nondecreasing order with multiplicity, from `k = 0`,
  by the Courant–Fischer min–max principle on Tau Ceti's Sobolev spaces: the `k`-th Dirichlet
  eigenvalue is `TauCeti.PDE.dirichletEigenvalue volume Ω (fun _ ↦ 1) 0 0 k` (on `H¹₀(Ω)`) and
  the `k`-th Neumann eigenvalue is `TauCeti.PDE.mixedEigenvalue volume Ω ∅ (fun _ ↦ 1) 0 0 k`
  (Dirichlet condition on `Γ = ∅`, on `H¹_∅(Ω)`, which is `H¹(Ω)` for a bounded Lipschitz
  domain). Isospectrality is equality of these sequences.
* Isometric means congruent: some isometry of the plane carries the ellipse onto `Ω`.
-/

open MeasureTheory TopologicalSpace Set
open scoped ContDiff

noncomputable section

namespace HezariZelditch

/-- A **smooth domain** in the plane: a nonempty, connected, bounded open set `{x | ρ x < 0}`
for a smooth function `ρ` whose derivative does not vanish on `{ρ = 0}`, so that its boundary
is the smooth curve `{ρ = 0}`. -/
def IsSmoothDomain (Ω : Opens (EuclideanSpace ℝ (Fin 2))) : Prop :=
  IsConnected (Ω : Set (EuclideanSpace ℝ (Fin 2))) ∧
    Bornology.IsBounded (Ω : Set (EuclideanSpace ℝ (Fin 2))) ∧
    ∃ ρ : EuclideanSpace ℝ (Fin 2) → ℝ, ContDiff ℝ ∞ ρ ∧
      (Ω : Set (EuclideanSpace ℝ (Fin 2))) = {x | ρ x < 0} ∧
      ∀ x, ρ x = 0 → fderiv ℝ ρ x ≠ 0

/-- The open **elliptical domain** `{x | (x₀ / a)² + (x₁ / b)² < 1}` with semi-axes `a` and `b`
along the coordinate axes. -/
def ellipse (a b : ℝ) : Opens (EuclideanSpace ℝ (Fin 2)) :=
  ⟨{x | (x 0 / a) ^ 2 + (x 1 / b) ^ 2 < 1}, isOpen_lt (by fun_prop) continuous_const⟩

/-- The **eccentricity** `√(1 - (b / a)²)` of the ellipse with semi-major axis `a` and
semi-minor axis `b`. -/
def eccentricity (a b : ℝ) : ℝ := Real.sqrt (1 - (b / a) ^ 2)

/-- The `k`-th **Dirichlet eigenvalue** of `-Δ` on `Ω`, from `k = 0`, with multiplicity. -/
abbrev dirichletEigenvalue (Ω : Opens (EuclideanSpace ℝ (Fin 2))) (k : ℕ) : ℝ :=
  TauCeti.PDE.dirichletEigenvalue volume Ω (fun _ ↦ 1) 0 0 k

/-- The `k`-th **Neumann eigenvalue** of `-Δ` on `Ω`, from `k = 0`, with multiplicity. -/
abbrev neumannEigenvalue (Ω : Opens (EuclideanSpace ℝ (Fin 2))) (k : ℕ) : ℝ :=
  TauCeti.PDE.mixedEigenvalue volume Ω ∅ (fun _ ↦ 1) 0 0 k

/-- **Hezari–Zelditch, Theorem 1.1.** There is `ε > 0` such that every smooth domain with the
Dirichlet spectrum, or the Neumann spectrum, of an ellipse of eccentricity less than `ε` is
isometric to that ellipse. -/
@[eval_problem]
theorem ellipse_spectrally_determined :
    ∃ ε > 0, ∀ a b : ℝ, 0 < b → b ≤ a → eccentricity a b < ε →
      ∀ Ω : Opens (EuclideanSpace ℝ (Fin 2)), IsSmoothDomain Ω →
        ((∀ k, dirichletEigenvalue Ω k = dirichletEigenvalue (ellipse a b) k) ∨
          (∀ k, neumannEigenvalue Ω k = neumannEigenvalue (ellipse a b) k)) →
        ∃ φ : EuclideanSpace ℝ (Fin 2) ≃ᵢ EuclideanSpace ℝ (Fin 2),
          φ '' (ellipse a b : Set (EuclideanSpace ℝ (Fin 2))) = Ω := by
  sorry

end HezariZelditch
