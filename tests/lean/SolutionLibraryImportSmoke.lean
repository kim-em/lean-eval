import EvalTools.RunEval

open LeanEvalGenerator.Core EvalTools

set_option autoImplicit false

/-- Score a solved workspace importing an optional solution library through the
production comparator without changing the generated baseline or repeating
full-catalog validation. -/
def main (args : List String) : IO Unit := do
  unless args.length == 1 do
    throw <| IO.userError "Expected the workspace directory"
  let root ← IO.currentDir
  let problems ← selectedProblems (← loadManifest root) #["two_plus_two"]
  buildExtractor root problems
  let scores ← scoreProblems root problems (root / args.head!)
  let summary := summarizeScores scores
  unless summary.attemptedProblems == 1 && summary.succeededProblems == 1 do
    throw <| IO.userError (renderHumanSummary scores summary)
  IO.println "Solution-library import scored successfully through comparator and NanoDa."
