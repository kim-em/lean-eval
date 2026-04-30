import Mathlib
import Submission.Helpers
/-!
Minimal example exercising `instance` holes in the multi-hole
eval-problem pipeline. The carrier type is itself a hole so the source
has no non-hole declarations and the generator does not need a
`ChallengeDeps` split.
-/

namespace Submission

def WidgetCarrier : Type := sorry
instance instInhabitedWidget : Inhabited WidgetCarrier := sorry

end Submission
