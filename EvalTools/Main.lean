import Cli
import EvalTools.CheckComparatorInstallation
import EvalTools.CheckEvalWorkflow
import EvalTools.CheckGeneratedBuilds
import EvalTools.CheckProblemBuild
import EvalTools.Generate
import EvalTools.Markers
import EvalTools.RepoRoot
import EvalTools.RunEval
import EvalTools.StartProblem
import EvalTools.ValidateManifest
import EvalTools.ValidateSubmission

open Cli

namespace EvalTools

set_option autoImplicit false

def runRootCmd (p : Parsed) : IO UInt32 := do
  p.printHelp
  pure 0

def runValidateManifestCmd (p : Parsed) : IO UInt32 := do
  let root ← requireRepoRoot
  EvalTools.runValidateManifest root (modulesBuilt := p.hasFlag "assume-modules-built")

def runCheckProblemBuildCmd (_ : Parsed) : IO UInt32 := do
  let root ← requireRepoRoot
  EvalTools.runCheckProblemBuild root

def runGenerateCmd (p : Parsed) : IO UInt32 := do
  let root ← requireRepoRoot
  let manifest? : Option String := p.flag? "manifest" |>.map fun f => f.as! String
  -- The `--manifest` flag selects an alternative manifest directory. The Lean
  -- port supports only the repo-default `manifests/problems/`; non-default
  -- paths would need a separate code path in `loadManifest`, which no caller
  -- has needed. Refuse the flag explicitly rather than silently ignoring it.
  if let some path := manifest? then
    if path != "manifests/problems" then
      IO.eprintln s!"--manifest currently only supports the default path (got {path})."
      return 1
  let problem? : Option String := p.flag? "problem" |>.map fun f => f.as! String
  let check := p.hasFlag "check"
  try
    EvalTools.generate root problem? check
    return 0
  catch e =>
    IO.eprintln (toString e)
    return 1

def runCheckGeneratedBuildsCmd (p : Parsed) : IO UInt32 := do
  let problems :=
    match p.flag? "problem" with
    | some flag => flag.as! (Array String)
    | none => #[]
  let root ← requireRepoRoot
  EvalTools.runCheckGeneratedBuilds root problems

def runStartProblemCmd (p : Parsed) : IO UInt32 := do
  let problemId : String := p.positionalArg! "problem-id" |>.as! String
  let destinations : Array String := p.variableArgsAs! String
  if destinations.size > 1 then
    IO.eprintln "start-problem accepts at most one destination path."
    return 1
  let root ← requireRepoRoot
  let sourceDisplay := s!"generated/{problemId}"
  let sourcePath := root / "generated" / problemId
  let destinationStr? : Option String := destinations[0]?
  let (destinationDisplay, destinationPath) := match destinationStr? with
    | some d =>
        let path : System.FilePath := d
        let effective := if path.isAbsolute then path else root / path
        (d, effective)
    | none =>
        let display := s!"workspaces/{problemId}"
        (display, root / "workspaces" / problemId)
  EvalTools.runStartProblem sourcePath sourceDisplay destinationPath destinationDisplay

def runCheckComparatorInstallationCmd (_ : Parsed) : IO UInt32 := do
  let root ← requireRepoRoot
  EvalTools.runCheckComparatorInstallation root

def runRunEvalCmd (p : Parsed) : IO UInt32 := do
  let manifest? : Option String := p.flag? "manifest" |>.map fun f => f.as! String
  if let some path := manifest? then
    if path != "manifests/problems" then
      IO.eprintln s!"--manifest currently only supports the default path (got {path})."
      return 1
  let selected : Array String :=
    match p.flag? "problem" with
    | some flag => flag.as! (Array String)
    | none => #[]
  let emitJson := p.hasFlag "json"
  let root ← requireRepoRoot
  let workspacesRoot : System.FilePath :=
    match p.flag? "workspaces-root" with
    | some flag =>
        let raw : String := flag.as! String
        let path : System.FilePath := raw
        if path.isAbsolute then path else root / raw
    | none => root / "workspaces"
  EvalTools.runRunEval root selected workspacesRoot emitJson

def runValidateSubmissionCmd (p : Parsed) : IO UInt32 := do
  let base? : Option String := p.flag? "base" |>.map fun f => f.as! String
  let head? : Option String := p.flag? "head" |>.map fun f => f.as! String
  let files : Array String :=
    match p.flag? "file" with
    | some flag => flag.as! (Array String)
    | none => #[]
  let emitJson := p.hasFlag "json"
  let root ← requireRepoRoot
  EvalTools.runValidateSubmission root base? head? files emitJson

def runCheckEvalWorkflowCmd (_ : Parsed) : IO UInt32 := do
  let root ← requireRepoRoot
  EvalTools.runCheckEvalWorkflow root

def validateManifestCmd : Cmd := `[Cli|
  "validate-manifest" VIA runValidateManifestCmd;
  "Validate that the problem manifest matches the `@[eval_problem]` theorem inventory."

  FLAGS:
    "assume-modules-built"; "Skip rebuilding problem modules that a preceding check already built."
]

def checkProblemBuildCmd : Cmd := `[Cli|
  "check-problem-build" VIA runCheckProblemBuildCmd;
  "Build the trusted problem modules and fail on Lean warnings or errors."
]

def generateCmd : Cmd := `[Cli|
  generate VIA runGenerateCmd;
  "Generate comparator workspaces from the trusted problem sources."

  FLAGS:
    manifest : String; "Path to the problem manifest."
    problem : String;  "Generate only the workspace for the given problem id."
    check;             "Check whether generated output is up to date without rewriting files."
]

def checkGeneratedBuildsCmd : Cmd := `[Cli|
  "check-generated-builds" VIA runCheckGeneratedBuildsCmd;
  "Build generated workspaces to catch breakage in emitted projects."

  FLAGS:
    problem : Array String; "Restrict the build check to the given problem id. Pass repeatedly or as `--problem id1,id2`."
]

def startProblemCmd : Cmd := `[Cli|
  "start-problem" VIA runStartProblemCmd;
  "Copy a generated problem workspace into a local working directory."

  ARGS:
    "problem-id" : String; "Problem identifier, for example `two_plus_two`."
    ...destination : String; "Optional destination directory. Defaults to `workspaces/<problem-id>`."
]

def checkComparatorInstallationCmd : Cmd := `[Cli|
  "check-comparator-installation" VIA runCheckComparatorInstallationCmd;
  "Run a real comparator check against the starter workspace."
]

def runEvalCmd : Cmd := `[Cli|
  "run-eval" VIA runRunEvalCmd;
  "Score local workspaces by running comparator on attempted problems."

  FLAGS:
    manifest : String;               "Path to the problem manifest."
    problem : Array String;          "Restrict scoring to the given problem id. Pass repeatedly or as `--problem id1,id2`."
    json;                            "Emit machine-readable JSON output."
    "workspaces-root" : String;      "Directory containing local problem workspaces. Defaults to `./workspaces`."
]

def validateSubmissionCmd : Cmd := `[Cli|
  "validate-submission" VIA runValidateSubmissionCmd;
  "Validate that changed files stay within the current submission whitelist."

  FLAGS:
    base : String;        "Base git ref for changed-file validation."
    head : String;        "Head git ref for changed-file validation."
    file : Array String;  "Explicit changed file path. Pass repeatedly or as `--file path1,path2`."
    json;                 "Emit machine-readable JSON output."
]

def checkEvalWorkflowCmd : Cmd := `[Cli|
  "check-eval-workflow" VIA runCheckEvalWorkflowCmd;
  "Run the end-to-end local workflow self-check."
]

def leanEvalCmd : Cmd := `[Cli|
  "lean-eval" VIA runRootCmd; ["0.1.0"]
  "Command-line entrypoint for generating, validating, and scoring the Lean benchmark."

  SUBCOMMANDS:
    validateManifestCmd;
    checkProblemBuildCmd;
    generateCmd;
    checkGeneratedBuildsCmd;
    startProblemCmd;
    checkComparatorInstallationCmd;
    runEvalCmd;
    validateSubmissionCmd;
    checkEvalWorkflowCmd

  EXTENSIONS:
    author "OpenAI Codex"
]

/--
Coalesce repeated `--<name> v1 --<name> v2 ...` occurrences into a single
`--<name> v1,v2,...` occurrence. lean4-cli's `Array String` flag instance
parses one occurrence as a comma-separated list and rejects the second
occurrence with `Duplicate flag`. Pre-processing here lets users also pass
the flag the natural way (matching argparse, gh, etc.).
-/
def coalesceRepeatedFlag (args : List String) (name : String) : List String := Id.run do
  let argsArr := args.toArray
  let mut collected : Array String := #[]
  let mut kept : Array String := #[]
  let mut i := 0
  while i < argsArr.size do
    if argsArr[i]! == name && i + 1 < argsArr.size then
      collected := collected.push argsArr[i + 1]!
      i := i + 2
    else
      kept := kept.push argsArr[i]!
      i := i + 1
  if collected.size ≤ 1 then return args
  return kept.toList ++ [name, ",".intercalate collected.toList]

def runMain (args : List String) : IO UInt32 := do
  let args := coalesceRepeatedFlag args "--problem"
  let args := coalesceRepeatedFlag args "--file"
  leanEvalCmd.validate args

end EvalTools

def main (args : List String) : IO UInt32 :=
  EvalTools.runMain args
