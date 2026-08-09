import Lean
import EvalTools.Markers
import EvalTools.Subprocess

open Lean

namespace EvalTools

set_option autoImplicit false

/-- Path of the manifest directory, relative to the repository root.
Each problem lives in its own file `manifests/problems/<id>.toml`. -/
def defaultManifestRelativePath : System.FilePath :=
  "manifests" / "problems"

private def isAsciiAlnum (c : Char) : Bool :=
  c.isAlpha || c.isDigit

/-- Mirrors the Python `ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")`. -/
private def isValidProblemId (s : String) : Bool :=
  !s.isEmpty
    && isAsciiAlnum s.front
    && s.all (fun c => isAsciiAlnum c || c == '_' || c == '-')

/-- Stem of a `*.toml` file (basename without the trailing `.toml`). -/
private def tomlStem (path : System.FilePath) : String :=
  let base := path.fileName.getD ""
  if base.endsWith ".toml" then (base.dropEnd 5).toString else base

/-- Load and validate the manifest directory. Walks
`manifests/problems/*.toml` in sorted order, parses each file as a
single problem entry, and enforces:

* `id` matches the filename stem (catches copy-paste typos);
* `id` satisfies the ASCII `ID_PATTERN` from `scripts/generate_projects.py`;
* required fields and non-empty `holes` (via `parseManifestEntry`);
* `id` and `(module, hole)` uniqueness across all entries. -/
def loadManifest (root : System.FilePath) : IO (Array EvalProblemMetadata) := do
  let manifestDir := root / defaultManifestRelativePath
  unless ← manifestDir.isDir do
    throw <| IO.userError
      s!"Manifest directory `{manifestDir}` does not exist or is not a directory."
  let mut rawFiles : Array System.FilePath := #[]
  for entry in (← manifestDir.readDir) do
    -- Reject rather than skip: a manifest saved as `<id>.lean` used to drop out
    -- of the catalog silently, taking its problem module with it (issue #519).
    -- The exemption is `.DS_Store` alone, not dotfiles in general: the
    -- `@[eval_problem]` elaborator reads every `*.toml` here (`Markers.lean`),
    -- so skipping a hidden `.foo.toml` would let it claim a tagged declaration
    -- that never reaches the catalog.
    if entry.fileName == ".DS_Store" then
      continue
    if ← entry.path.isDir then
      throw <| IO.userError
        s!"`{entry.path}` is a directory; `manifests/problems/` holds one `<id>.toml` file per problem."
    unless entry.path.extension == some "toml" do
      throw <| IO.userError
        s!"`{entry.path}` is not a `.toml` file; `manifests/problems/` holds one `<id>.toml` file per problem."
    rawFiles := rawFiles.push entry.path
  let files := rawFiles.qsort fun a b =>
    (a.fileName.getD "") < (b.fileName.getD "")
  let mut entries : Array EvalProblemMetadata := #[]
  let mut seenIds : Std.HashSet String := {}
  let mut seenRefs : Std.HashSet (String × String) := {}
  for file in files do
    let contents ← IO.FS.readFile file
    let entry ←
      match ← parseManifestEntry contents file.toString with
      | .ok m => pure m
      | .error err => throw <| IO.userError err
    let expectedId := tomlStem file
    unless entry.id == expectedId do
      throw <| IO.userError
        s!"Manifest entry in `{file}` has id `{entry.id}` but filename stem is `{expectedId}`; the two must match."
    unless isValidProblemId entry.id do
      throw <| IO.userError
        s!"Problem id '{entry.id}' is invalid. Use only letters, digits, '_' or '-'."
    if seenIds.contains entry.id then
      throw <| IO.userError s!"Duplicate problem id `{entry.id}` across files in `manifests/problems/`."
    seenIds := seenIds.insert entry.id
    for hole in entry.holes do
      let key := (entry.moduleName, hole)
      if seenRefs.contains key then
        throw <| IO.userError
          s!"Duplicate hole reference `{entry.moduleName}:{hole}` across files in `manifests/problems/`."
      seenRefs := seenRefs.insert key
    entries := entries.push entry
  return entries

/-- Preserve the order of first occurrence (matches Python's `unique_modules`). -/
def uniqueModules (entries : Array EvalProblemMetadata) : Array String := Id.run do
  let mut seen : Std.HashSet String := {}
  let mut out : Array String := #[]
  for entry in entries do
    unless seen.contains entry.moduleName do
      seen := seen.insert entry.moduleName
      out := out.push entry.moduleName
  return out

/-- Result row from the `eval_inventory` tool. Mirrors
`scripts/generate_projects.py`'s `InventoryEntry`. -/
structure ManifestInventoryEntry where
  module : String
  declarationName : String
  basename : String
  kind : String
  deriving Inhabited

private def parseInventoryEntries (payload : String) :
    Except String (Array ManifestInventoryEntry) := do
  let json ← Json.parse payload
  let arr ← json.getArr?
  let mut out : Array ManifestInventoryEntry := #[]
  for raw in arr do
    let module ← raw.getObjValAs? String "module"
    let declarationName ← raw.getObjValAs? String "declarationName"
    let basename ← raw.getObjValAs? String "basename"
    let kind ← raw.getObjValAs? String "kind"
    out := out.push
      { module := module, declarationName := declarationName,
        basename := basename, kind := kind }
  return out

/-- Build the Lake targets and run the `eval_inventory` executable over every
module referenced by `entries`.

Build the inventory executable first, then each problem module separately.
Passing every problem module to one `lake build` lets Lake schedule the entire
catalog at once, which can exhaust machine resources on a clean checkout. -/
def runInventoryTool (root : System.FilePath) (modules : Array String) :
    IO (Array ManifestInventoryEntry) := do
  let _ ← runCmdCheckedCaptured "lake"
    #["build", "eval_inventory"] root
    "Failed to build Lean problem inventory tool"
  for moduleName in modules do
    let _ ← runCmdCheckedCaptured "lake"
      #["build", moduleName] root
      s!"Failed to build Lean problem module '{moduleName}'"
  let binPath := root / ".lake" / "build" / "bin" / "eval_inventory"
  let out ← runCmdCheckedCaptured "lake"
    (#["env", binPath.toString] ++ modules) root
    "Lean problem inventory failed"
  match parseInventoryEntries out.stdout with
  | .ok entries => pure entries
  | .error err => throw <| IO.userError s!"Problem inventory returned invalid JSON: {err}"

/-- Match Python's `gp.validate_manifest_against_inventory`: ensure every
manifest hole resolves to exactly one `@[eval_problem]`-tagged declaration,
and every such declaration appears in the manifest. -/
def validateManifestAgainstInventory
    (root : System.FilePath) (entries : Array EvalProblemMetadata) : IO Unit := do
  let modules := uniqueModules entries
  let inventory ← runInventoryTool root modules
  let mut byModule : Std.HashMap String (Array ManifestInventoryEntry) := {}
  for inv in inventory do
    byModule := byModule.insert inv.module
      ((byModule.getD inv.module #[]).push inv)
  let mut matched : Std.HashSet String := {}
  for problem in entries do
    let moduleInventory := byModule.getD problem.moduleName #[]
    for hole in problem.holes do
      let candidates := moduleInventory.filter fun inv =>
        inv.basename == hole || inv.declarationName == hole
      if candidates.isEmpty then
        throw <| IO.userError
          s!"Manifest entry '{problem.id}' references hole '{hole}' which has no @[eval_problem] declaration in module '{problem.moduleName}'."
      if candidates.size > 1 then
        throw <| IO.userError
          s!"Manifest entry '{problem.id}' hole '{hole}' is ambiguous in module '{problem.moduleName}'. Use a fully qualified name."
      matched := matched.insert candidates[0]!.declarationName
  let untracked := inventory.filterMap fun inv =>
    if matched.contains inv.declarationName then none else some inv.declarationName
  if !untracked.isEmpty then
    let sorted := untracked.qsort (· < ·)
    let joined := ", ".intercalate sorted.toList
    throw <| IO.userError
      s!"Tagged @[eval_problem] declaration(s) are missing from manifests/problems/: {joined}"

end EvalTools
