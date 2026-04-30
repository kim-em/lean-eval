import Mathlib
import Submission
/-!
# Jacobians of compact Riemann surfaces

Kevin Buzzard's "Jacobian Challenge" v0.3, posted to leanprover Zulip
(`#Autoformalization > Jacobian challenge`):
<https://leanprover.zulipchat.com/#narrow/stream/583336-Autoformalization/topic/Jacobian%20challenge>.
The original source uses anonymous instances; here every `instance` is
named explicitly so the eval-problem pipeline can address it.

## Main missing definitions

* `genus` -- genus of a compact Riemann surface
* `Jacobian` -- the Jacobian of a compact Riemann surface
* `Jacobian.ofCurve` -- the Abel-Jacobi map from a compact Riemann surface to its Jacobian
* `ContMDiff.degree` -- the degree of a holomorphic map between compact Riemann surfaces.
    Equal to 0 if the map is constant, otherwise equal to the usual degree.
* `Jacobian.pushforward` -- the pushforward map on Jacobians induced by a holomorphic map between
  compact Riemann surfaces.
* `Jacobian.pullback` -- the pullback map on Jacobians induced by a holomorphic map between
  compact Riemann surfaces.

## Main missing theorems

* `genus_eq_zero_iff_homeo` -- a compact Riemann surface has genus 0 iff it is homeomorphic to the sphere
* `ofCurve_inj` -- the Abel-Jacobi map is injective iff the genus is positive
* `Jacobian.ofCurve_contMDiff` -- the Abel-Jacobi map is holomorphic
* `Jacobian.pushforward_contMDiff` -- the pushforward map is holomorphic
* `Jacobian.pullback_contMDiff` -- the pullback map is holomorphic
* `pushforward_pullback` -- pullback then pushforward is multiplication by degree
-/

open scoped ContDiff -- for ω notation

namespace JacobianChallenge

universe u v w

-- let X be a compact Riemann surface
variable {X : Type u} [TopologicalSpace X] [T2Space X] [CompactSpace X] [ConnectedSpace X]
  [ChartedSpace ℂ X] [IsManifold (modelWithCornersSelf ℂ ℂ) ω X]

-- data
@[reducible] def genus (X : Type u) [TopologicalSpace X] [T2Space X] [CompactSpace X] [ConnectedSpace X]
    [Nonempty X] [ChartedSpace ℂ X] [IsManifold (modelWithCornersSelf ℂ ℂ) ω X] : ℕ := Submission.JacobianChallenge.genus X

-- this proof avoids the hack answer `∀ X, genus X = 0`
-- Prop
theorem genus_eq_zero_iff_homeo :
    genus X = 0 ↔ Nonempty (X ≃ₜ (Metric.sphere (0 : EuclideanSpace ℝ (Fin 3)) 1)) := Submission.JacobianChallenge.genus_eq_zero_iff_homeo

-- data
@[reducible] def Jacobian (X : Type u) [TopologicalSpace X] [T2Space X] [CompactSpace X] [ConnectedSpace X]
    [Nonempty X] [ChartedSpace ℂ X] [IsManifold (modelWithCornersSelf ℂ ℂ) ω X] : Type u := Submission.JacobianChallenge.Jacobian X

namespace Jacobian

-- data
@[reducible] instance instAddCommGroup : AddCommGroup (Jacobian X) := Submission.JacobianChallenge.Jacobian.instAddCommGroup

-- data
@[reducible] instance instTopologicalSpace : TopologicalSpace (Jacobian X) := Submission.JacobianChallenge.Jacobian.instTopologicalSpace

-- Prop
instance instT2Space : T2Space (Jacobian X) := Submission.JacobianChallenge.Jacobian.instT2Space

-- Prop
instance instCompactSpace : CompactSpace (Jacobian X) := Submission.JacobianChallenge.Jacobian.instCompactSpace

@[reducible] instance instChartedSpace : ChartedSpace (Fin (genus X) → ℂ) (Jacobian X) := Submission.JacobianChallenge.Jacobian.instChartedSpace

-- Prop
instance instIsManifold :
    IsManifold (modelWithCornersSelf ℂ (Fin (genus X) → ℂ)) ω (Jacobian X) := Submission.JacobianChallenge.Jacobian.instIsManifold

-- Prop
instance instLieAddGroup :
    LieAddGroup (modelWithCornersSelf ℂ (Fin (genus X) → ℂ)) ω (Jacobian X) := Submission.JacobianChallenge.Jacobian.instLieAddGroup

@[reducible] def ofCurve (P : X) : X → Jacobian X := Submission.JacobianChallenge.Jacobian.ofCurve P

theorem ofCurve_contMDiff (P : X) :
    ContMDiff (modelWithCornersSelf ℂ ℂ)
      (modelWithCornersSelf ℂ (Fin (genus X) → ℂ)) ω (ofCurve P) := Submission.JacobianChallenge.Jacobian.ofCurve_contMDiff P

theorem ofCurve_self (P : X) : ofCurve P P = 0 := Submission.JacobianChallenge.Jacobian.ofCurve_self P

-- this is the lemma which stops the hack answer "J(X)=0 for all X"
theorem ofCurve_inj (P : X) (h : 0 < genus X) : Function.Injective (ofCurve P) := Submission.JacobianChallenge.Jacobian.ofCurve_inj P h

variable {Y : Type v} [TopologicalSpace Y] [T2Space Y] [CompactSpace Y] [ConnectedSpace Y]
  [Nonempty Y] [ChartedSpace ℂ Y] [IsManifold (modelWithCornersSelf ℂ ℂ) ω Y]

variable (f : X → Y) (hf : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω f)

@[reducible] def pushforward (f : X → Y)
    (hf : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω f) :
    Jacobian X →ₜ+ Jacobian Y := Submission.JacobianChallenge.Jacobian.pushforward f hf

theorem pushforward_contMDiff (f : X → Y)
    (hf : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω f) :
    ContMDiff (modelWithCornersSelf ℂ (Fin (genus X) → ℂ))
      (modelWithCornersSelf ℂ (Fin (genus Y) → ℂ)) ω (pushforward f hf) := Submission.JacobianChallenge.Jacobian.pushforward_contMDiff f hf

-- functoriality
theorem pushforward_id_apply (P : Jacobian X) :
    pushforward id contMDiff_id P = P := Submission.JacobianChallenge.Jacobian.pushforward_id_apply P

variable {Z : Type w} [TopologicalSpace Z] [T2Space Z] [CompactSpace Z] [ConnectedSpace Z]
  [Nonempty Z] [ChartedSpace ℂ Z] [IsManifold (modelWithCornersSelf ℂ ℂ) ω Z]

variable (g : Y → Z) (hg : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω g)

theorem pushforward_comp_apply (f : X → Y)
    (hf : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω f)
    (g : Y → Z) (hg : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω g)
    (P : Jacobian X) :
    pushforward (g ∘ f) (hg.comp hf) P = pushforward g hg (pushforward f hf P) := Submission.JacobianChallenge.Jacobian.pushforward_comp_apply f hf g hg P

-- if f is constant then the pullback should be the zero map, otherwise it's
-- the usual pullback
@[reducible] def pullback (f : X → Y)
    (hf : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω f) :
    Jacobian Y →ₜ+ Jacobian X := Submission.JacobianChallenge.Jacobian.pullback f hf

theorem pullback_contMDiff (f : X → Y)
    (hf : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω f) :
    ContMDiff (modelWithCornersSelf ℂ (Fin (genus Y) → ℂ))
      (modelWithCornersSelf ℂ (Fin (genus X) → ℂ)) ω (pullback f hf) := Submission.JacobianChallenge.Jacobian.pullback_contMDiff f hf

theorem pullback_id_apply (P : Jacobian X) :
    pullback id contMDiff_id P = P := Submission.JacobianChallenge.Jacobian.pullback_id_apply P

theorem pullback_comp_apply (f : X → Y)
    (hf : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω f)
    (g : Y → Z) (hg : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω g)
    (P : Jacobian Z) :
    pullback (g.comp f) (hg.comp hf) P = pullback f hf (pullback g hg P) := Submission.JacobianChallenge.Jacobian.pullback_comp_apply f hf g hg P

@[reducible] def degree (f : X → Y)
    (hf : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω f) : ℕ := Submission.JacobianChallenge.Jacobian.degree f hf -- 0 for constant case

theorem pushforward_pullback (f : X → Y)
    (hf : ContMDiff (modelWithCornersSelf ℂ ℂ) (modelWithCornersSelf ℂ ℂ) ω f)
    (P : Jacobian Y) :
    pushforward f hf (pullback f hf P) = (degree f hf) • P := Submission.JacobianChallenge.Jacobian.pushforward_pullback f hf P

end Jacobian

end JacobianChallenge
