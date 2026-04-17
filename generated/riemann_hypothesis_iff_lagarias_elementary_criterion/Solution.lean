import ChallengeDeps
import Submission

open FormalMathEval.NumberTheory
open scoped ArithmeticFunction.sigma

theorem riemann_hypothesis_iff_lagarias_elementary_criterion :
    RiemannHypothesis ↔ LagariasElementaryCriterion := by
  exact Submission.riemann_hypothesis_iff_lagarias_elementary_criterion
