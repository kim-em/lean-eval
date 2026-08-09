import EvalTools.Manifest
import EvalTools.ModuleCoverage

namespace EvalTools

set_option autoImplicit false

/-- Implementation of `lake exe lean-eval validate-manifest`. Loads the
manifest (which already enforces id/holes/duplication rules), checks that it
reaches every problem module, and cross-checks against the `@[eval_problem]`
inventory built from source.

The coverage check comes first because it is the only one that does not need a
build, and because the inventory cross-check is blind to modules the manifest
never names.

The Python original also called `gp.validate_hole_shape`, a textual pre-check
for typos in hole names. That check is purely redundant with the inventory
cross-check (which goes through the elaborator), so it is dropped here. -/
def runValidateManifest (root : System.FilePath) : IO UInt32 := do
  try
    let entries ← loadManifest root
    checkProblemModuleCoverage root entries
    validateManifestAgainstInventory root entries
    IO.println "Manifest and @[eval_problem] declarations are consistent."
    return 0
  catch err =>
    IO.eprintln err
    return 1

end EvalTools
