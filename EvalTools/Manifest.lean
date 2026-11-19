import LeanEvalGenerator.Core.Manifest

namespace EvalTools

/-- Select the problems or modules supported by the workspace's exact dependency pins. -/
def configurationSelection (root : System.FilePath) (args : Array String) : IO (Array String) := do
  let output ← LeanEvalGenerator.Core.runCmdCheckedCaptured "python3"
    (#[s!"{root / "scripts" / "problem_configurations.py"}"] ++ args) root
    "Could not select supported problems"
  match Lean.Json.parse output.stdout >>= Lean.fromJson? (α := Array String) with
  | .ok values => return values
  | .error err => throw <| IO.userError s!"Invalid configuration selection: {err}"

/-- Reject attempts to generate or start a problem on unsupported dependencies. -/
def requireSupportedProblem (root : System.FilePath) (problem : String) : IO Unit := do
  let _ ← LeanEvalGenerator.Core.runCmdCheckedCaptured "python3"
    #[s!"{root / "scripts" / "problem_configurations.py"}", "--problem", problem] root
    s!"Problem '{problem}' is not supported by this configuration"

/-- Use the supported catalog by default and validate explicitly requested problems. -/
def supportedProblemSelection (root : System.FilePath) (requested : Array String) : IO (Array String) := do
  if requested.isEmpty then
    return ← configurationSelection root #["--list-problems"]
  for problem in requested do
    requireSupportedProblem root problem
  return requested

/-- Keep all metadata in supported modules so inventory still detects untracked declarations. -/
def compatibleManifestEntries (root : System.FilePath)
    (entries : Array LeanEvalGenerator.Core.EvalProblemMetadata) :
    IO (Array LeanEvalGenerator.Core.EvalProblemMetadata) := do
  let modules ← configurationSelection root #["--modules", "", "--json"]
  return entries.filter fun entry => modules.contains entry.moduleName

end EvalTools
