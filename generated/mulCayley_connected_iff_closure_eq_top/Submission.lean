import Mathlib
import Submission.Helpers

namespace Submission

theorem mulCayley_connected_iff_closure_eq_top {G : Type*} [Group G]
    (S : Set G) :
    (SimpleGraph.mulCayley S).Connected ↔ Subgroup.closure S = ⊤ := by
  sorry

end Submission
