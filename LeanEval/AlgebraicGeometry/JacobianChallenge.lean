/-
Copyright (c) 2026 Christian Merten. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Christian Merten
-/
import Mathlib
import EvalTools.Markers

/-!
# Jacobians in algebraic geometry

Christian Merten's algebraic-geometry analogue of Kevin Buzzard's Jacobian
challenge, posted to leanprover Zulip:
<https://leanprover.zulipchat.com/#narrow/stream/583336-Autoformalization/topic/Jacobian%20challenge/near/587802685>.

In the following, by a smooth curve we mean a geometrically irreducible, smooth scheme of relative
dimension one over a field.

## Main missing definitions

* `AlgebraicGeometry.JacobianChallenge.genus` -- genus of a proper, smooth curve
* `AlgebraicGeometry.JacobianChallenge.Jacobian` -- the Jacobian of a proper, smooth curve
* `AlgebraicGeometry.JacobianChallenge.Jacobian.ofCurve` -- the Abel-Jacobi map from a proper smooth
  curve to its Jacobian

## Main missing theorems

* `Jacobian.smoothOfRelativeDimension_genus` -- The Jacobian of a proper, smooth curve `C` is smooth
  of relative dimension `g`, where `g` is the genus of `C`.
* `Jacobian.exists_unique_ofCurve_comp` -- the universal property of the Jacobian of a proper,
  smooth curve.
-/

set_option autoImplicit false

universe u

open CategoryTheory Limits MonoidalCategory CartesianMonoidalCategory MonObj

namespace AlgebraicGeometry

namespace JacobianChallenge

-- We make `C` implicit at the variable level so that instance and `def` holes
-- whose statement references the outer `C` (e.g. `instance instGrpObj :
-- GrpObj (Jacobian C) := sorry`) elaborate to a Π-type with `{C}` implicit;
-- otherwise the eval-pipeline's `Solution.lean` would have to thread a `C`
-- argument through every delegation. Decls that genuinely need `C` explicit
-- (e.g. `genus`, `Jacobian`, `comp_ofCurve`) supply their own `(C : ...)`
-- binder.
variable {k : Type u} [Field k] {C : Over (Spec (.of k))}
  -- smooth curve
  [SmoothOfRelativeDimension 1 C.hom]
  -- proper
  [IsProper C.hom]
  -- geometrically irreducible
  [GeometricallyIrreducible C.hom]

-- data
/-- The genus of a smooth proper curve. -/
@[eval_problem]
def genus (C : Over (Spec (.of k))) [IsProper C.hom] [SmoothOfRelativeDimension 1 C.hom]
    [GeometricallyIrreducible C.hom] : ℕ :=
  sorry

-- data
/-- The Jacobian of a smooth, proper curve over a field `k`. -/
@[eval_problem]
def Jacobian (C : Over (Spec (.of k))) [IsProper C.hom] [SmoothOfRelativeDimension 1 C.hom]
    [GeometricallyIrreducible C.hom] : Over (Spec (.of k)) :=
  sorry

namespace Jacobian

/-! ## The Jacobian of `C` is an abelian variety. -/

-- data
/-- The group scheme structure on the Jacobian of the curve `C`. -/
@[eval_problem]
instance instGrpObj : GrpObj (Jacobian C) :=
  sorry

/-- The Jacobian of `C` is smooth of relative dimension `g` over `k`, where `g` is the
genus of `C`. -/
@[eval_problem]
instance smoothOfRelativeDimension_genus :
    SmoothOfRelativeDimension (genus C) (Jacobian C).hom :=
  sorry

/-- The Jacobian of `C` is proper over `k`. -/
@[eval_problem]
instance instIsProper : IsProper (Jacobian C).hom :=
  sorry

/-- The Jacobian of `C` is geometrically irreducible over `k`. -/
@[eval_problem]
instance instGeometricallyIrreducible : GeometricallyIrreducible (Jacobian C).hom :=
  sorry

-- data
/-- The Abel-Jacobi map from a smooth, proper curve to its Jacobian associated
to a `k`-rational point of `C`. -/
@[eval_problem]
def ofCurve (P : 𝟙_ (Over (Spec (.of k))) ⟶ C) : C ⟶ Jacobian C :=
  sorry

/-- The Abel-Jacobi map sends the `k`-rational point `P` to `0`, where `0` (denoted by `η` below) is
the neutral element of the group scheme `Jacobian C`. -/
@[eval_problem]
theorem comp_ofCurve (C : Over (Spec (.of k))) [IsProper C.hom]
    [SmoothOfRelativeDimension 1 C.hom] [GeometricallyIrreducible C.hom]
    (P : 𝟙_ (Over (Spec (.of k))) ⟶ C) :
    P ≫ ofCurve P = η[Jacobian C] :=
  sorry

/--
The universal property of the Jacobian variety: For any abelian variety `A`,
any morphism `f : C ⟶ A` such that `f(P) = 0` factors uniquely through the
Jacobian of `C`.
In other words, `Jacobian C` is the Albanese variety of `C`.
-/
@[eval_problem]
theorem exists_unique_ofCurve_comp (C : Over (Spec (.of k))) [IsProper C.hom]
    [SmoothOfRelativeDimension 1 C.hom] [GeometricallyIrreducible C.hom]
    (P : 𝟙_ (Over (Spec (.of k))) ⟶ C)
    {A : Over (Spec (.of k))} [Smooth A.hom] [IsProper A.hom] [GrpObj A]
    [GeometricallyIrreducible A.hom] (f : C ⟶ A) (hf : P ≫ f = η[A]) :
    ∃! (g : Jacobian C ⟶ A), f = ofCurve P ≫ g :=
  sorry

end Jacobian

end JacobianChallenge

end AlgebraicGeometry
