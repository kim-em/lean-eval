import Mathlib
import EvalTools.Markers

/-!
Minimal example exercising `instance` holes in the multi-hole
eval-problem pipeline. The carrier type is itself a hole so the source
has no non-hole declarations and the generator does not need a
`ChallengeDeps` split.
-/

@[eval_problem]
def WidgetCarrier : Type := sorry

@[eval_problem]
instance instInhabitedWidget : Inhabited WidgetCarrier := sorry
