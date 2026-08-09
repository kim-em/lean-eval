import Lean
import EvalTools.Markers

open Lean

namespace EvalTools

set_option autoImplicit false

/-- Directory holding the trusted problem sources, relative to the repository
root. Its module prefix is the directory name. -/
def problemSourceRelativePath : System.FilePath := "LeanEval"

/-- A `.lean` file under `LeanEval/`, together with the modules its header
imports.

Module identity is a `Name`, not a string: `LeanEval/Foo/Bar.lean` is
`LeanEval.Foo.Bar` while `LeanEval/Foo.Bar.lean` is `LeanEval.«Foo.Bar»`, and
flattening either to text would conflate two distinct files. -/
structure ProblemSourceModule where
  /-- Fully qualified module name, for example
  `LeanEval.Geometry.JacobianChallenge`. -/
  name : Name
  /-- Path of the file, relative to the repository root. -/
  path : String
  /-- The modules named in the file's `import` header. -/
  imports : Array Name
  deriving Inhabited, Repr

private def sourcesByName (sources : Array ProblemSourceModule) :
    Std.HashMap Name ProblemSourceModule :=
  sources.foldl (fun m source => m.insert source.name source) ∅

/-- Mark `name` and everything it transitively imports as reached. Imports that
name no module in `byName` (Mathlib, `EvalTools.Markers`, ...) are recorded but
not followed. -/
private partial def markReachable (byName : Std.HashMap Name ProblemSourceModule)
    (reached : Std.HashSet Name) (name : Name) : Std.HashSet Name :=
  if reached.contains name then
    reached
  else
    let reached := reached.insert name
    match byName[name]? with
    | none => reached
    | some source => source.imports.foldl (markReachable byName) reached

/-- The modules of `sources` that are neither listed in `roots` nor reachable
from `roots` by following imports. Order follows `sources`. -/
def unreachableModules (sources : Array ProblemSourceModule) (roots : Array Name) :
    Array Name :=
  let byName := sourcesByName sources
  let reached := roots.foldl (markReachable byName) ∅
  sources.filterMap fun source =>
    if reached.contains source.name then none else some source.name

/-- Recursively collect the `.lean` files under `dir`, reading each header for
its imports. `relDir` and `modulePrefix` describe `dir` itself. -/
private partial def collectSourceModules (dir : System.FilePath) (relDir : String)
    (modulePrefix : Name) : IO (Array ProblemSourceModule) := do
  let entries := (← dir.readDir).qsort fun a b => a.fileName < b.fileName
  let mut out : Array ProblemSourceModule := #[]
  for entry in entries do
    let relPath := s!"{relDir}/{entry.fileName}"
    -- `symlinkMetadata` rather than `isDir`: the latter follows links, so a
    -- directory symlink could duplicate a subtree under a second module prefix,
    -- or point at an ancestor and recurse forever.
    match (← entry.path.symlinkMetadata).type with
    | .symlink =>
        throw <| IO.userError
          s!"`{relPath}` is a symbolic link. Problem sources must be regular files and \
             directories, so that a file's path determines its module name."
    | .dir =>
        out := out ++ (← collectSourceModules entry.path relPath (modulePrefix.str entry.fileName))
    | _ =>
        if entry.path.extension == some "lean" then
          let stem := (entry.fileName.dropEnd 5).toString
          let header ← parseImports' (← IO.FS.readFile entry.path) entry.path.toString
          out := out.push
            { name := modulePrefix.str stem
              path := relPath
              imports := header.imports.map (·.module) }
  return out

/-- Fail unless every `.lean` file under `LeanEval/` is reachable from the
manifest: either named by some entry's `module` field, or imported (directly or
transitively) by a module that is.

Nothing else walks the problem sources, so a module the manifest cannot reach is
never compiled and never validated; it can carry a broken statement and leave CI
green. See https://github.com/leanprover/lean-eval/issues/519.

This is a header-level check: it parses imports rather than building anything,
so it costs no build time and runs before the inventory cross-check. -/
def checkProblemModuleCoverage
    (root : System.FilePath) (entries : Array EvalProblemMetadata) : IO Unit := do
  let sourceRoot := root / problemSourceRelativePath
  unless ← sourceRoot.isDir do
    throw <| IO.userError
      s!"Problem source directory `{sourceRoot}` does not exist or is not a directory."
  let prefixName := problemSourceRelativePath.toString
  let sources ← collectSourceModules sourceRoot prefixName (.str .anonymous prefixName)
  let known := sources.foldl (fun s source => s.insert source.name) (∅ : Std.HashSet Name)
  let missing := entries.filterMap fun entry =>
    if known.contains (parseModuleName entry.moduleName) then none
    else some s!"  {entry.moduleName} (manifests/problems/{entry.id}.toml)"
  if !missing.isEmpty then
    throw <| IO.userError <|
      "Manifest entries name modules that have no source file under `LeanEval/`:\n"
        ++ "\n".intercalate missing.toList
        ++ "\nCheck the `module` field for a typo, or add the missing file."
  let unreachable := unreachableModules sources (entries.map (parseModuleName ·.moduleName))
  if !unreachable.isEmpty then
    let byName := sourcesByName sources
    let described := unreachable.map fun name =>
      match byName[name]? with
      | some source => s!"  {name} ({source.path})"
      | none => s!"  {name}"
    throw <| IO.userError <|
      "No manifest entry reaches the following module(s), so CI never builds them:\n"
        ++ "\n".intercalate described.toList
        ++ "\nEvery file under `LeanEval/` must be named by the `module` field of some \
            `manifests/problems/<id>.toml`, or be imported (directly or transitively) by a \
            module that is. If you did write a manifest for one of these, check that it sits \
            in `manifests/problems/` and that its name ends in `.toml`; if the file is a \
            leftover, delete it."

end EvalTools
