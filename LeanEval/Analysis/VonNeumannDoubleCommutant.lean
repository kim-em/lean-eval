import Mathlib.Analysis.VonNeumannAlgebra.Basic
import Mathlib.Analysis.InnerProductSpace.WeakOperatorTopology
import Mathlib.Topology.Algebra.Module.Spaces.PointwiseConvergenceCLM
import EvalTools.Markers

namespace LeanEval
namespace Analysis

/-!
Von Neumann's double commutant theorem.

For a unital *-subalgebra `S` of bounded operators on a complex Hilbert space `H`, the
following are equivalent:

1. `S` equals its double commutant `S''`.
2. `S` is closed in the weak operator topology.
3. `S` is closed in the strong operator topology (in Mathlib, the topology of pointwise
   convergence on continuous linear maps).

The WOT and SOT live on irreducible type copies of `H →L[ℂ] H`, so each closed-ness
condition is stated as the closedness of the image of `S` under the canonical inclusion
into the corresponding type copy.
-/

@[eval_problem]
theorem vonNeumann_doubleCommutant_tfae
    {H : Type*} [NormedAddCommGroup H] [InnerProductSpace ℂ H] [CompleteSpace H]
    (S : StarSubalgebra ℂ (H →L[ℂ] H)) :
    List.TFAE
      [ Set.centralizer (Set.centralizer (S : Set (H →L[ℂ] H))) = S
      , IsClosed
          (ContinuousLinearMap.toWOT (RingHom.id ℂ) H H '' (S : Set (H →L[ℂ] H)))
      , IsClosed
          (ContinuousLinearMap.toPointwiseConvergenceCLM ℂ (RingHom.id ℂ) H H ''
            (S : Set (H →L[ℂ] H))) ] := by
  sorry

end Analysis
end LeanEval
