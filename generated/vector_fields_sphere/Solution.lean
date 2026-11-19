import ChallengeDeps
import Submission

open LeanEval.Topology.VectorFieldsSphere

theorem maxNumVecFieldsSphere_eq_radonHurwitz_sub_one (n : ℕ+) :
    maxNumVecFieldsSphere n = radonHurwitz n - 1 := by
  exact Submission.maxNumVecFieldsSphere_eq_radonHurwitz_sub_one n
