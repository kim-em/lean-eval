/-
Copyright (c) 2026 Thomas Browning. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Thomas Browning
-/

import Mathlib.Algebra.Group.Pointwise.Set.Basic
import Mathlib.Algebra.MonoidAlgebra.MapDomain
import Mathlib.Basic.Real.Basic
import Mathlib.GroupTheory.FreeGroup.Basic
import Mathlib.SetTheory.Cardinal.Finite
import EvalTools.Markers

/-!
# Main Statement from On property (T) for Aut(F_n) and SL_n(Z)

We formalise the statement of the main result from M. Kaluba, D. Kielak, and P. W. Nowak,
`On property (T) for Aut(F_n) and SL_n(Z)`, Annals of Math, 193 (2) 2021.
-/

set_option autoImplicit false

open scoped Pointwise

namespace OnPropertyT

/-- For a group `G` with a finite symmetric generating set `S`, the Laplacian element is
the element `|S| - ∑_{s ∈ S} s` of `ℝG`, as defined in Equation (1) of the paper. -/
noncomputable def Laplacian {G : Type*} [Group G] (S : Finset G) : MonoidAlgebra ℝ G :=
  Nat.card S - ∑ s ∈ S, MonoidAlgebra.of ℝ G s

/-- Conjugation on `ℝG` is defined by inversion. -/
noncomputable instance (G : Type*) [Group G] : Star (MonoidAlgebra ℝ G) where
  star := MonoidAlgebra.mapDomain (· ⁻¹)

/-- Kazhdan's Property (T), as defined in Equation (2) of the paper. -/
def PropertyT (G : Type*) [Group G] : Prop :=
  ∃ S : Finset G, (S : Set G)⁻¹ = S ∧ Subgroup.closure (S : Set G) = ⊤ ∧ ∃ Λ : ℝ, Λ > 0 ∧
    ∃ ξ : Finset (MonoidAlgebra ℝ G), Laplacian S ^ 2 - Λ • Laplacian S = ∑ ξi ∈ ξ, star ξi * ξi

/--
Statement of Theorem 1:

`Aut(F_n)` has property (T) for all `n ≥ 6`.
-/
@[eval_problem]
theorem theorem_1 (n : ℕ) (hn : n ≥ 6) : PropertyT (MulAut (FreeGroup (Fin n))) := by
  sorry

end OnPropertyT
