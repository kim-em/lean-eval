import Mathlib
import Submission

theorem list_append_singleton_length :
    (([1, 2] : List Nat).append [3]).length = 3 := by
  exact @Submission.list_append_singleton_length
