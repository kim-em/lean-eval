import Cli
import EvalTools.Markers

open Cli

namespace EvalTools

set_option autoImplicit false

partial def findRepoRoot? (dir : System.FilePath) : IO (Option System.FilePath) := do
  let hasLakefile ← (dir / "lakefile.toml").pathExists
  let hasManifest ← (dir / "manifests" / "problems.toml").pathExists
  if hasLakefile && hasManifest then
    return some dir
  match dir.parent with
  | none => return none
  | some parent =>
      if parent == dir then
        return none
      findRepoRoot? parent

def requireRepoRoot : IO System.FilePath := do
  let cwd ← IO.currentDir
  let some root ← findRepoRoot? cwd
    | throw <| IO.userError
        "Could not find the repository root. Run `lake exe lean-eval ...` from this repo or a subdirectory of it."
  pure root

def commandExists (cmd : String) : IO Bool := do
  try
    let child ← IO.Process.spawn {
      cmd := "sh"
      args := #["-c", "command -v \"$1\" >/dev/null 2>&1", "sh", cmd]
    }
    return (← child.wait) == 0
  catch _ =>
    return false

def pythonCommand : IO String := do
  if ← commandExists "python3" then
    pure "python3"
  else if ← commandExists "python" then
    pure "python"
  else
    throw <| IO.userError
      "Could not find `python3` or `python` in PATH. The current `lean-eval` implementation still shells out to the existing Python scripts."

def runPythonScript (script : String) (args : Array String := #[]) : IO UInt32 := do
  let root ← requireRepoRoot
  let python ← pythonCommand
  let child ← IO.Process.spawn {
    cmd := python
    args := #[script] ++ args
    cwd := root
    stdin := .inherit
    stdout := .inherit
    stderr := .inherit
  }
  child.wait

def appendFlag (args : Array String) (name : String) (enabled : Bool) : Array String :=
  if enabled then args.push name else args

def appendFlagValue (args : Array String) (name : String) (value? : Option String) : Array String :=
  match value? with
  | some value => args.push name |>.push value
  | none => args

def appendRepeatedFlagValues (args : Array String) (name : String) (values : Array String) : Array String :=
  values.foldl (fun acc value => acc.push name |>.push value) args

def runRootCmd (p : Parsed) : IO UInt32 := do
  p.printHelp
  pure 0

def runValidateManifestCmd (_ : Parsed) : IO UInt32 :=
  runPythonScript "scripts/validate_manifest.py"

def runCheckProblemBuildCmd (_ : Parsed) : IO UInt32 :=
  runPythonScript "scripts/check_problem_build.py"

def runGenerateCmd (p : Parsed) : IO UInt32 := do
  let mut args : Array String := #[]
  args := appendFlagValue args "--manifest" <| (p.flag? "manifest" |>.map fun f => f.as! String)
  args := appendFlagValue args "--problem" <| (p.flag? "problem" |>.map fun f => f.as! String)
  args := appendFlag args "--check" (p.hasFlag "check")
  runPythonScript "scripts/generate_projects.py" args

def runCheckGeneratedBuildsCmd (p : Parsed) : IO UInt32 := do
  let problems :=
    match p.flag? "problem" with
    | some flag => flag.as! (Array String)
    | none => #[]
  let args := appendRepeatedFlagValues #[] "--problem" problems
  runPythonScript "scripts/check_generated_builds.py" args

def runStartProblemCmd (p : Parsed) : IO UInt32 := do
  let problemId : String := p.positionalArg! "problem-id" |>.as! String
  let destinations : Array String := p.variableArgsAs! String
  if destinations.size > 1 then
    IO.eprintln "start-problem accepts at most one destination path."
    return 1
  let mut args := #[problemId]
  if let some destination := destinations[0]? then
    args := args.push destination
  runPythonScript "scripts/start_problem.py" args

def runCheckComparatorInstallationCmd (_ : Parsed) : IO UInt32 :=
  runPythonScript "scripts/check_comparator_installation.py"

def runRunEvalCmd (p : Parsed) : IO UInt32 := do
  let mut args : Array String := #[]
  args := appendFlagValue args "--manifest" <| (p.flag? "manifest" |>.map fun f => f.as! String)
  args := appendRepeatedFlagValues args "--problem" <|
    match p.flag? "problem" with
    | some flag => flag.as! (Array String)
    | none => #[]
  args := appendFlag args "--json" (p.hasFlag "json")
  args := appendFlagValue args "--workspaces-root" <| (p.flag? "workspaces-root" |>.map fun f => f.as! String)
  runPythonScript "scripts/run_eval.py" args

def runValidateSubmissionCmd (p : Parsed) : IO UInt32 := do
  let mut args : Array String := #[]
  args := appendFlagValue args "--base" <| (p.flag? "base" |>.map fun f => f.as! String)
  args := appendFlagValue args "--head" <| (p.flag? "head" |>.map fun f => f.as! String)
  args := appendRepeatedFlagValues args "--file" <|
    match p.flag? "file" with
    | some flag => flag.as! (Array String)
    | none => #[]
  args := appendFlag args "--json" (p.hasFlag "json")
  runPythonScript "scripts/validate_submission.py" args

def runCheckEvalWorkflowCmd (_ : Parsed) : IO UInt32 :=
  runPythonScript "scripts/check_eval_workflow.py"

def validateManifestCmd : Cmd := `[Cli|
  "validate-manifest" VIA runValidateManifestCmd;
  "Validate that the problem manifest matches the `@[eval_problem]` theorem inventory."
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
