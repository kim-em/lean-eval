import Mathlib
import Submission.Helpers

namespace Submission

theorem isStarNormal_mul_of_commute {A : Type*} [NonUnitalCStarAlgebra A]
    {a b : A} (ha : IsStarNormal a) (hb : IsStarNormal b)
    (hab : Commute a b) :
    IsStarNormal (a * b) := by
  sorry

end Submission
