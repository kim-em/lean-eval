import ChallengeDeps
import Submission

open OnPropertyT
open scoped Pointwise

set_option autoImplicit false

theorem theorem_1 (n : ℕ) (hn : n ≥ 6) : PropertyT (MulAut (FreeGroup (Fin n))) := by
  exact Submission.theorem_1 n hn
