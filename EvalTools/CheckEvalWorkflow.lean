import EvalTools.Generate
import EvalTools.Manifest
import EvalTools.Markers
import EvalTools.RunEval
import EvalTools.StartProblem

set_option linter.deprecated false

open Lean

namespace EvalTools

set_option autoImplicit false

private def TWO_PLUS_TWO_ID : String := "two_plus_two"

/-- Replace the first occurrence of `placeholder` in `text` with `replacement`. -/
private def replaceFirst (text placeholder replacement : String) : Option String := Id.run do
  let parts := text.splitOn placeholder
  if parts.length < 2 then return none
  let head := parts.head!
  let rest := parts.tail
  let tail := placeholder.intercalate rest
  return some (head ++ replacement ++ tail)

/-- Replace `  sorry\n` in `Submission.lean` with `replacement`. Mirrors
`replace_placeholder` in `check_eval_workflow.py`. -/
private def replacePlaceholder (workspace : System.FilePath) (replacement : String) :
    IO Unit := do
  let submissionPath := workspace / "Submission.lean"
  let original ← IO.FS.readFile submissionPath
  match replaceFirst original "  sorry\n" replacement with
  | none =>
      throw <| IO.userError s!"Expected placeholder proof in {submissionPath}"
  | some updated =>
      IO.FS.writeFile submissionPath updated

private def prepareTwoPlusTwoWorkspace (root : System.FilePath)
    (workspacesRoot : System.FilePath) : IO System.FilePath := do
  let source := root / "generated" / TWO_PLUS_TWO_ID
  if !(← source.isDir) then
    throw <| IO.userError s!"Missing generated workspace: {source}"
  let destination := workspacesRoot / TWO_PLUS_TWO_ID
  if let some parent := destination.parent then
    IO.FS.createDirAll parent
  copyTree source destination
  return destination

/-- Point a copied workspace at the root project's already-populated dependency
tree. Both projects use the exact Mathlib revision from the root lakefile, so
cloning and decompressing the same multi-gigabyte cache again only adds latency.
The workspace keeps its own build directory; only immutable dependencies are
shared. -/
private def reuseRootPackages (root workspace : System.FilePath) : IO Unit := do
  let rootPackages := root / ".lake" / "packages"
  let rootManifest := root / "lake-manifest.json"
  unless (← rootPackages.isDir) && (← rootManifest.pathExists) do
    return
  let workspaceLake := workspace / ".lake"
  IO.FS.createDirAll workspaceLake
  let packagesLink := workspaceLake / "packages"
  let _ ← runCmdCheckedCaptured "ln" #["-s", rootPackages.toString, packagesLink.toString]
    root "Failed to share the root Lake package cache with the eval workspace"
  IO.FS.writeFile (workspace / "lake-manifest.json") (← IO.FS.readFile rootManifest)

private def assertCounts (summary : ScoreSummary) (attempted succeeded : Nat) (label : String) :
    IO Unit := do
  if summary.attemptedProblems != attempted || summary.succeededProblems != succeeded then
    throw <| IO.userError <|
      s!"{label} produced unexpected results.\n" ++
      s!"Expected attempted={attempted}, succeeded={succeeded}.\n" ++
      s!"Actual summary: attempted={summary.attemptedProblems}, succeeded={summary.succeededProblems} (test attempted/succeeded={summary.attemptedTestProblems}/{summary.succeededTestProblems}, main attempted/succeeded={summary.attemptedMainProblems}/{summary.succeededMainProblems})"

private def summarizeAtRoot (root : System.FilePath) (problems : Array EvalProblemMetadata)
    (workspacesRoot : System.FilePath) : IO ScoreSummary := do
  let scores ← scoreProblems root problems workspacesRoot
  return summarizeScores scores

/-- Implementation of `lake exe lean-eval check-eval-workflow`. -/
def runCheckEvalWorkflow (root : System.FilePath) : IO UInt32 := do
  let runBody : IO UInt32 := show IO UInt32 from do
    -- This is an end-to-end smoke test for the scoring path, not a second
    -- catalog-wide generation check. CI validates and builds the full catalog
    -- independently; repeating that work here used to dominate the workflow.
    try
      generate root (selectedProblemId := some TWO_PLUS_TWO_ID) (check := true)
    catch e =>
      throw <| IO.userError <|
        "The generated two_plus_two smoke-test workspace is stale.\n" ++
        "Run `lake exe lean-eval generate --problem two_plus_two`, then rerun " ++
        "this check.\n\nDetails:\n" ++ toString e
    let allProblems ← loadManifest root
    let problems ← selectedProblems allProblems #[TWO_PLUS_TWO_ID]
    buildExtractor root problems
    -- Use a tempdir under REPO_ROOT so `workspace_path` resolves relative to root.
    let tempName : String := s!"lean-eval-workflow-{← IO.rand 0 1000000000}"
    let tempDir := root / tempName
    IO.FS.createDirAll tempDir
    try
      let workspacesRoot := tempDir / "workspaces"
      let initialSummary ← summarizeAtRoot root problems workspacesRoot
      assertCounts initialSummary 0 0 "Pristine eval"
      let workspace ← prepareTwoPlusTwoWorkspace root workspacesRoot
      reuseRootPackages root workspace
      let pristineSubmission ← IO.FS.readFile (workspace / "Submission.lean")
      replacePlaceholder workspace "  exact (by omega : (2 : Nat) + 2 = 5)\n"
      let incorrectSummary ← summarizeAtRoot root problems workspacesRoot
      assertCounts incorrectSummary 1 0 "Incorrect two_plus_two attempt"
      IO.FS.writeFile (workspace / "Submission.lean")
        (replaceFirst pristineSubmission "  sorry\n" "  norm_num\n").get!
      let correctSummary ← summarizeAtRoot root problems workspacesRoot
      assertCounts correctSummary 1 1 "Correct two_plus_two attempt"
      IO.println "Eval workflow check passed."
      IO.FS.removeDirAll tempDir
      return (0 : UInt32)
    catch e =>
      try IO.FS.removeDirAll tempDir catch _ => pure ()
      throw e
  try
    runBody
  catch e =>
    IO.eprintln (toString e)
    return (1 : UInt32)

end EvalTools
