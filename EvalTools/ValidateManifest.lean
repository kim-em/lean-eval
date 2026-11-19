import EvalTools.Manifest
import EvalTools.ModuleCoverage

namespace EvalTools

open LeanEvalGenerator.Core

set_option autoImplicit false

/-- Implementation of `lake exe lean-eval validate-manifest`. Loads the
manifest (which already enforces id/holes/duplication rules), checks that it
reaches every problem module, and cross-checks against the `@[eval_problem]`
inventory built from source.

The coverage check comes first because it is the only one that does not need a
build, and because the inventory cross-check is blind to modules the manifest
never names.

`structureOnly` runs the cheap global checks without importing compiled
modules. `inventoryDir?` validates JSON collected by parallel CI shards;
`requestedModules` narrows that validation for dependency-selected PRs.
`modulesBuilt` remains an optimization for callers using the original
single-process inventory path after `check-problem-build`.

The Python original also called `gp.validate_hole_shape`, a textual pre-check
for typos in hole names. That check is purely redundant with the inventory
cross-check (which goes through the elaborator), so it is dropped here. -/
def runValidateManifest (root : System.FilePath) (modulesBuilt : Bool := false)
    (structureOnly : Bool := false) (inventoryDir? : Option System.FilePath := none)
    (requestedModules : Array String := #[]) : IO UInt32 := do
  try
    let entries ← loadManifest root
    let _ ← configurationSelection root #["--list-problems"]
    checkProblemModuleCoverage root entries
    if structureOnly then
      if inventoryDir?.isSome then
        throw <| IO.userError "--structure-only and --inventory-dir cannot be used together."
      IO.println "Manifest structure and problem-module coverage are consistent."
    else
      let compatible ← compatibleManifestEntries root entries
      match inventoryDir? with
      | some inventoryDir =>
          let inventory ← loadInventoryDirectory inventoryDir
          let modules ← selectManifestModules entries requestedModules
          let selected := modules.foldl
            (fun set moduleName => set.insert moduleName) ({} : Std.HashSet String)
          let selectedEntries := compatible.filter fun entry => selected.contains entry.moduleName
          validateManifestAgainstInventoryEntries selectedEntries inventory
      | none =>
          unless requestedModules.isEmpty do
            throw <| IO.userError "--module requires --inventory-dir."
          validateManifestAgainstInventory root compatible (buildModules := !modulesBuilt)
      IO.println "Manifest and @[eval_problem] declarations are consistent."
    return 0
  catch err =>
    IO.eprintln err
    return 1

end EvalTools
