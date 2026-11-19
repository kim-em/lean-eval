import EvalTools.Generate
import EvalTools.Manifest
import EvalTools.Markers

set_option linter.deprecated false

open Lean

namespace EvalTools

open LeanEvalGenerator.Core

set_option autoImplicit false

/-- Per-problem score, mirroring `run_eval.py`'s `ProblemScore` dataclass. -/
structure ProblemScore where
  id : String
  title : String
  visible : Bool
  attempted : Bool
  succeeded : Bool
  exitCode : Option UInt32
  mismatches : Array String
  workspacePath : String

def ProblemScore.toOJson (s : ProblemScore) : OJson :=
  ojObj #[
    ("id", ojStr s.id),
    ("title", ojStr s.title),
    ("visible", ojBool s.visible),
    ("attempted", ojBool s.attempted),
    ("succeeded", ojBool s.succeeded),
    ("exit_code", match s.exitCode with
      | none => OJson.null
      | some c => ojNat c.toNat),
    ("mismatches", ojStrArr s.mismatches),
    ("workspace_path", ojStr s.workspacePath)
  ]

def DEFAULT_WORKSPACES_DIR : System.FilePath := "workspaces"

/-- Determine which workspace dir to score for a given problem. Prefers
`<workspacesRoot>/<id>` if it exists; otherwise falls back to
`<root>/generated/<id>`. Mirrors `workspace_path_for_problem`. -/
def workspacePathForProblem (root : System.FilePath) (problemId : String)
    (workspacesRoot : System.FilePath) : IO System.FilePath := do
  let candidate := workspacesRoot / problemId
  if (← candidate.isDir) then return candidate
  return root / "generated" / problemId

/-- Run `lake test` in the given workspace, forwarding all output to stderr so
JSON-mode callers can keep their stdout clean. Mirrors `run_problem_test`.
Streams each chunk as it arrives so noisy / hanging child output doesn't
accumulate unbounded memory before the child exits. -/
def runProblemTest (workspace : System.FilePath)
    (env : Array (String × Option String) := #[]) : IO UInt32 := do
  let stderr ← IO.getStderr
  let child ← IO.Process.spawn {
    cmd := "lake"
    args := #["test"]
    cwd := workspace
    env
    stdin := .inherit
    stdout := .piped
    stderr := .piped
  }
  let outForward ← IO.asTask (do
    while true do
      let chunk ← child.stdout.read 4096
      if chunk.isEmpty then break
      stderr.write chunk)
  let errForward ← IO.asTask (do
    while true do
      let chunk ← child.stderr.read 4096
      if chunk.isEmpty then break
      stderr.write chunk)
  let exitCode ← child.wait
  let _ ← IO.wait outForward
  let _ ← IO.wait errForward
  return exitCode

/-- Resolve preparation tools before any submitted code runs. -/
private def resolveExecutable (name : String) : IO System.FilePath := do
  if name.contains System.FilePath.pathSeparator then
    return ← IO.FS.realPath name
  for dir in System.SearchPath.parse ((← IO.getEnv "PATH").getD "") do
    let candidate := dir / name
    if ← candidate.pathExists then
      return ← IO.FS.realPath candidate
  throw <| IO.userError s!"Missing evaluation tool: {name}"

/-- Make the trusted shared cache visible after Lake covers home and /tmp.
The wrapper runs with an empty environment, so all paths are embedded. -/
private def withCacheSandbox {α : Type} (root : System.FilePath)
    (f : Array (String × Option String) → IO α) : IO α := do
  let cache ← IO.FS.realPath (root / ".lake" / "packages")
  let bwrap ← resolveExecutable ((← IO.getEnv "COMPARATOR_BWRAP").getD "bwrap")
  let shell ← resolveExecutable "sh"
  IO.FS.withTempDir fun tmp => do
    let wrapper := tmp / "bwrap-with-cache"
    let quoted (path : System.FilePath) := "'" ++ path.toString.replace "'" "'\\''" ++ "'"
    IO.FS.writeFile wrapper <|
      s!"#!{shell}\ninserted=\nfor arg do\n  shift\n" ++
      "  if [ \"$arg\" = -- ] && [ -z \"$inserted\" ]; then\n" ++
      s!"    set -- \"$@\" --ro-bind {quoted cache} {quoted cache}\n" ++
      "    inserted=1\n  fi\n  set -- \"$@\" \"$arg\"\ndone\n" ++
      s!"exec {quoted bwrap} \"$@\"\n"
    IO.setAccessRights wrapper { user := { read := true, write := true, execution := true } }
    f #[("COMPARATOR_BWRAP", some wrapper.toString)]

/-- Score every problem in `problems`. Mirrors `score_problems`. -/
def scoreProblems (root : System.FilePath) (problems : Array EvalProblemMetadata)
    (workspacesRoot : System.FilePath) : IO (Array ProblemScore) := do
  withCacheSandbox root fun env => do
    score env
where
  score (env : Array (String × Option String)) : IO (Array ProblemScore) := do
    let toolchain ← IO.FS.readFile (root / "lean-toolchain")
    let deps ← loadRootDependencies root
    let workspaceTest ← loadWorkspaceTestTemplate root
    let mut scores : Array ProblemScore := #[]
    for entry in problems do
      let mut extracteds : Array ExtractedTheorem := #[]
      for hole in entry.holes do
        let e ← extractOne root entry hole
        extracteds := extracteds.push e
      let expectedFiles ← renderWorkspace root entry extracteds toolchain deps workspaceTest
      let workspace ← workspacePathForProblem root entry.id workspacesRoot
      let relDisplay :=
        let wsStr := workspace.toString
        let rootStr := root.toString ++ "/"
        if wsStr.startsWith rootStr then wsStr.drop rootStr.length |>.toString else wsStr
      let mismatches ← checkWorkspace workspace relDisplay expectedFiles
      let attempted := !mismatches.isEmpty
      let (exitCode?, succeeded) ←
        if attempted then
          let code ← runProblemTest workspace env
          if code == 2 then
            throw <| IO.userError s!"Comparator could not run for {entry.id}; see the setup diagnostics above."
          pure (some code, code == 0)
        else
          pure (none, false)
      scores := scores.push {
        id := entry.id
        title := entry.title
        visible := entry.visible
        attempted := attempted
        succeeded := succeeded
        exitCode := exitCode?
        mismatches := mismatches
        workspacePath := relDisplay
      }
    return scores

/-- Aggregated counts. Mirrors `summarize_scores`. -/
structure ScoreSummary where
  totalProblems : Nat
  attemptedProblems : Nat
  succeededProblems : Nat
  attemptedHiddenProblems : Nat
  succeededHiddenProblems : Nat
  attemptedVisibleProblems : Nat
  succeededVisibleProblems : Nat

def summarizeScores (scores : Array ProblemScore) : ScoreSummary := Id.run do
  let attempted := scores.filter (·.attempted)
  let succeeded := attempted.filter (·.succeeded)
  let attemptedHidden := scores.filter fun s => s.attempted && !s.visible
  let succeededHidden := scores.filter fun s => s.succeeded && !s.visible
  let attemptedVisible := scores.filter fun s => s.attempted && s.visible
  let succeededVisible := scores.filter fun s => s.succeeded && s.visible
  return {
    totalProblems := scores.size
    attemptedProblems := attempted.size
    succeededProblems := succeeded.size
    attemptedHiddenProblems := attemptedHidden.size
    succeededHiddenProblems := succeededHidden.size
    attemptedVisibleProblems := attemptedVisible.size
    succeededVisibleProblems := succeededVisible.size
  }

def summaryToOJson (scores : Array ProblemScore) (s : ScoreSummary) : OJson :=
  ojObj #[
    ("total_problems", ojNat s.totalProblems),
    ("attempted_problems", ojNat s.attemptedProblems),
    ("succeeded_problems", ojNat s.succeededProblems),
    ("attempted_hidden_problems", ojNat s.attemptedHiddenProblems),
    ("succeeded_hidden_problems", ojNat s.succeededHiddenProblems),
    ("attempted_visible_problems", ojNat s.attemptedVisibleProblems),
    ("succeeded_visible_problems", ojNat s.succeededVisibleProblems),
    ("problems", ojArr (scores.map ProblemScore.toOJson))
  ]

/-- Human-readable summary. Mirrors `render_human_summary`. -/
def renderHumanSummary (scores : Array ProblemScore) (s : ScoreSummary) : String := Id.run do
  let mut lines : Array String := #[
    s!"Attempted {s.attemptedProblems} / {s.totalProblems} problems; succeeded on {s.succeededProblems}.",
    s!"Hidden problems: attempted {s.attemptedHiddenProblems}; succeeded on {s.succeededHiddenProblems}.",
    s!"Visible problems: attempted {s.attemptedVisibleProblems}; succeeded on {s.succeededVisibleProblems}."
  ]
  for sc in scores do
    let status :=
      if !sc.attempted then "unattempted"
      else if sc.succeeded then "passed"
      else "failed"
    let visibility := if sc.visible then "visible" else "hidden"
    lines := lines.push s!"- {sc.id} [{visibility}]: {status}"
  return "\n".intercalate lines.toList

/-- Filter problems by id. Mirrors `selected_problems`. -/
def selectedProblems (all : Array EvalProblemMetadata) (selectedIds : Array String) :
    IO (Array EvalProblemMetadata) := do
  if selectedIds.isEmpty then return all
  let wanted : Std.HashSet String := selectedIds.foldl (·.insert ·) {}
  let selected := all.filter fun p => wanted.contains p.id
  let foundIds : Std.HashSet String := selected.foldl (fun acc p => acc.insert p.id) {}
  let missing := (wanted.toArray.filter (!foundIds.contains ·)).qsort (· < ·)
  if !missing.isEmpty then
    throw <| IO.userError s!"Unknown problem id(s): {", ".intercalate missing.toList}"
  return selected

/-- Implementation of `lake exe lean-eval run-eval`. -/
def runRunEval (root : System.FilePath) (selectedIds : Array String)
    (workspacesRoot : System.FilePath) (emitJson : Bool) : IO UInt32 := do
  try
    let problems ← loadManifest root
    -- Validate every module supported on these dependencies before narrowing
    -- to requested problems. Keep all metadata in each module for inventory.
    let compatible ← compatibleManifestEntries root problems
    validateManifestAgainstInventory root compatible
    let selected ← selectedProblems problems selectedIds
    -- `score_problems` builds the extractor on demand; pre-build here so the
    -- output stays clean of "Built ..." noise once scoring begins.
    buildExtractor root selected
    let scores ← scoreProblems root selected workspacesRoot
    let summary := summarizeScores scores
    if emitJson then
      IO.println (OJson.pretty (summaryToOJson scores summary))
    else
      IO.println (renderHumanSummary scores summary)
    return 0
  catch e =>
    if emitJson then
      IO.println <| OJson.pretty <| ojObj #[
        ("status", ojStr "error"),
        ("message", ojStr (toString e))
      ]
    else
      IO.eprintln (toString e)
    return 1

end EvalTools
