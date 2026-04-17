import Mathlib.Analysis.Complex.Circle
import Mathlib.Data.ZMod.Basic
import Mathlib.Geometry.Manifold.Instances.Sphere
import Mathlib.Topology.Homotopy.HomotopyGroup
import EvalTools.Markers

namespace LeanEval
namespace Topology

/-!
Benchmark statements for classical unstable homotopy groups of spheres.

We use explicit basepoints throughout. This keeps the statements close to Mathlib's current APIs,
where homotopy groups are based.
-/

/-- The fundamental group of the complex unit circle is infinite cyclic. -/
@[eval_problem]
theorem pi1_circle_mulEquiv_int :
    Nonempty (HomotopyGroup.Pi 1 Circle (1 : Circle) ≃* Multiplicative ℤ) := by
  sorry

/-- The third homotopy group of the 2-sphere is infinite cyclic. -/
@[eval_problem]
theorem pi3_sphere_two_mulEquiv_int
    (x : Metric.sphere (0 : EuclideanSpace ℝ (Fin 3)) 1) :
    Nonempty
      (HomotopyGroup.Pi 3 (Metric.sphere (0 : EuclideanSpace ℝ (Fin 3)) 1) x ≃*
        Multiplicative ℤ) := by
  sorry

/-- For every `n ≥ 1`, the `n`th homotopy group of the `n`-sphere is infinite cyclic. -/
@[eval_problem]
theorem pin_sphere_n_mulEquiv_int
    (n : ℕ)
    (x : Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 2))) 1) :
    Nonempty
      (HomotopyGroup.Pi (n + 1) (Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 2))) 1) x ≃*
        Multiplicative ℤ) := by
  sorry

/-- A concrete stable-family statement: for `n ≥ 3`, `π_(n+1)(S^n) ≃ ℤ/2`. -/
@[eval_problem]
theorem pi_succ_sphere_n_mulEquiv_zmod_two
    (n : ℕ) (hn : 3 ≤ n)
    (x : Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 1))) 1) :
    Nonempty
      (HomotopyGroup.Pi (n + 1) (Metric.sphere (0 : EuclideanSpace ℝ (Fin (n + 1))) 1) x ≃*
        Multiplicative (ZMod 2)) := by
  sorry

end Topology
end LeanEval
