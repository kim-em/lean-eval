import Mathlib.Analysis.Calculus.IteratedDeriv.Defs
import Mathlib.Analysis.Complex.Basic
import EvalTools.Markers

namespace LeanEval.ComplexAnalysis

/-!
De Branges's theorem (Bieberbach conjecture)

From https://en.wikipedia.org/wiki/Louis_de_Branges_de_Bourcia#Works:
"De Branges' proof of the Bieberbach conjecture was not initially accepted by the mathematical
community. Rumors of his proof began to circulate in March 1984, but many mathematicians were
skeptical because de Branges had earlier announced some false (or inaccurate) results", ...
"It took verification by a team of mathematicians at Steklov Institute of Mathematics in Leningrad
to validate de Branges' proof, a process that took several months" ...

References:
John B. Conway, *Functions of One Complex Variable II*, Chapter 17.
https://en.wikipedia.org/wiki/De_Branges%27s_theorem
-/

open Metric

/-- De Branges's theorem (Bieberbach conjecture): a univalent function (injective holomorphic
function from the unit disc to the complex plane) with Taylor coefficients a₀=0 and a₁=1 satisfies
|aₙ|≤ n for all n. -/
@[eval_problem]
theorem deBranges (f : ℂ → ℂ) (diff : DifferentiableOn ℂ f (ball 0 1)) (inj : (ball 0 1).InjOn f)
    (h0 : f 0 = 0) (h1 : deriv f 0 = 1) (n : ℕ) : ‖iteratedDeriv n f 0 / n.factorial‖ ≤ n := by
  sorry

end LeanEval.ComplexAnalysis
