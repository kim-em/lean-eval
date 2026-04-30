import Mathlib
import EvalTools.Markers

/-!
Minimal example exercising the def-hole / multi-hole eval-problem pipeline.

A `def` and a `theorem` referring to it, both `sorry`. A submission
defines `Submission.foo := 37` and proves `Submission.foo_def`; comparator
should accept it.
-/

@[eval_problem]
def foo : Nat := sorry

@[eval_problem]
theorem foo_def : foo = 37 := sorry
