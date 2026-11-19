import EvalTools.Manifest

namespace EvalTools

open LeanEvalGenerator.Core

set_option autoImplicit false

private def hasSubstr (haystack pattern : String) : Bool :=
  (haystack.find? pattern).isSome

private def isDisallowedWarning (line : String) : Bool :=
  hasSubstr line "warning:" && !hasSubstr line "declaration uses `sorry`"

/-- Implementation of `lake exe lean-eval check-problem-build`. Builds each
manifest module separately via `lake build`, then scans captured output for
warnings other than the expected `declaration uses \`sorry\`` warnings the
problem modules emit by design.

The separate invocations are intentional: passing the complete catalog to one
`lake build` lets Lake schedule every independent module at once. -/
def runCheckProblemBuild (root : System.FilePath)
    (requestedModules : Array String := #[]) : IO UInt32 := do
  try
    let entries ← loadManifest root
    let requested ← selectManifestModules entries requestedModules
    let modules ← configurationSelection root
      #["--modules", ",".intercalate requested.toList, "--json"]
    let mut disallowed := []
    for moduleName in modules do
      let output ← runCmdCheckedCaptured "lake" #["build", moduleName] root
        s!"Problem module '{moduleName}' build failed"
      let combined :=
        [output.stdout, output.stderr].filter (! ·.isEmpty) |> String.intercalate "\n"
      disallowed := disallowed ++ (combined.splitOn "\n").filter isDisallowedWarning
    if !disallowed.isEmpty then
      IO.eprintln "Disallowed build warnings found:"
      for line in disallowed do
        IO.eprintln line
      return (1 : UInt32)
    IO.println "Problem modules built cleanly aside from expected `sorry` warnings."
    return (0 : UInt32)
  catch err =>
    IO.eprintln err
    return (1 : UInt32)

end EvalTools
