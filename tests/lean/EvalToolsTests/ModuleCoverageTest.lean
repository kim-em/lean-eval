import EvalTools.Manifest
import EvalTools.ModuleCoverage

open EvalTools

set_option autoImplicit false

private def assertEq {α : Type} [BEq α] [Repr α] (label : String)
    (actual expected : α) : Option String :=
  if actual == expected then none
  else some s!"{label}: expected {repr expected}, got {repr actual}"

private def assertContains (label haystack needle : String) : Option String :=
  if (haystack.find? needle).isSome then none
  else some s!"{label}: expected to contain {repr needle}, got {repr haystack}"

private def check (label : String) (passes fails : IO.Ref Nat)
    (f : IO (Option String)) : IO Unit := do
  match ← f.toBaseIO with
  | .ok none => IO.println s!"PASS: {label}"; passes.modify (· + 1)
  | .ok (some reason) =>
      IO.eprintln s!"FAIL: {label} — {reason}"
      fails.modify (· + 1)
  | .error err =>
      IO.eprintln s!"FAIL: {label} — unexpected exception: {err}"
      fails.modify (· + 1)

private def source (name : String) (imports : Array String) : ProblemSourceModule :=
  { name := parseModuleName name, path := name.replace "." "/" ++ ".lean",
    imports := imports.map parseModuleName }

private def moduleNames (names : Array Lean.Name) : Array String :=
  names.map toString

/-- A minimal repository: `manifests/problems/` plus a `LeanEval/` tree written
from `(relative path, contents)` pairs. -/
private def withFakeRepo (files : Array (String × String))
    (f : System.FilePath → IO (Option String)) : IO (Option String) := do
  let root ← IO.FS.createTempDir
  try
    IO.FS.createDirAll (root / "manifests" / "problems")
    for (relPath, contents) in files do
      let path := relPath.splitOn "/" |>.foldl (init := root) (· / ·)
      if let some parent := path.parent then
        IO.FS.createDirAll parent
      IO.FS.writeFile path contents
    f root
  finally
    try IO.FS.removeDirAll root catch _ => pure ()

private def problem (id moduleName : String) : EvalProblemMetadata :=
  { id := id, title := id, test := false, moduleName := moduleName,
    holes := #["hole"], submitter := "tester" }

def main : IO UInt32 := do
  let passes ← IO.mkRef 0
  let fails ← IO.mkRef 0

  -- Regression for https://github.com/leanprover/lean-eval/issues/519: a module
  -- no manifest reaches is never compiled, so a broken statement leaves CI green.
  check "unreachableModules reports a module no root reaches" passes fails do
    let sources := #[source "LeanEval.A" #[], source "LeanEval.Orphan" #[]]
    pure <| assertEq "unreachable"
      (moduleNames (unreachableModules sources #[`LeanEval.A])) #["LeanEval.Orphan"]

  check "unreachableModules follows imports transitively" passes fails do
    let sources := #[
      source "LeanEval.A" #["Mathlib", "LeanEval.B"],
      source "LeanEval.B" #["LeanEval.C"],
      source "LeanEval.C" #[]]
    pure <| assertEq "unreachable"
      (moduleNames (unreachableModules sources #[`LeanEval.A])) #[]

  -- Import cycles cannot occur in Lean, but the walk must not diverge if the
  -- headers on disk describe one.
  check "unreachableModules terminates on a cycle" passes fails do
    let sources := #[
      source "LeanEval.A" #["LeanEval.B"],
      source "LeanEval.B" #["LeanEval.A"],
      source "LeanEval.Orphan" #["LeanEval.Orphan"]]
    pure <| assertEq "unreachable"
      (moduleNames (unreachableModules sources #[`LeanEval.A])) #["LeanEval.Orphan"]

  -- Reachability is directed: importing a root does not make you reachable.
  check "unreachableModules does not follow imports backwards" passes fails do
    let sources := #[source "LeanEval.A" #[], source "LeanEval.Importer" #["LeanEval.A"]]
    pure <| assertEq "unreachable"
      (moduleNames (unreachableModules sources #[`LeanEval.A])) #["LeanEval.Importer"]

  -- A dot in a filename is a component separator only in the path, not in the
  -- module name: `LeanEval/Foo.Bar.lean` is `LeanEval.«Foo.Bar»`, a different
  -- module from `LeanEval/Foo/Bar.lean`. Flattening both to the text
  -- "LeanEval.Foo.Bar" would let a manifest entry for the nested file vouch for
  -- the sibling, which Lake never builds.
  check "checkProblemModuleCoverage separates Foo.Bar.lean from Foo/Bar.lean" passes fails do
    withFakeRepo
      #[("LeanEval/Foo/Bar.lean", "import Mathlib\n"),
        ("LeanEval/Foo.Bar.lean", "import Mathlib\n")] fun root => do
      match ← (checkProblemModuleCoverage root #[problem "bar" "LeanEval.Foo.Bar"]).toBaseIO with
      | .ok _ => pure (some "expected rejection")
      | .error err => pure <| assertContains "err" (toString err) "LeanEval/Foo.Bar.lean"

  -- The escaped spelling in a header (`«Foo-Bar»`) and the plain spelling on
  -- disk (`Foo-Bar.lean`) must resolve to the same module.
  check "checkProblemModuleCoverage matches an escaped import" passes fails do
    withFakeRepo
      #[("LeanEval/Claimed.lean", "import LeanEval.«Foo-Bar»\n"),
        ("LeanEval/Foo-Bar.lean", "import Mathlib\n")] fun root => do
      match ← (checkProblemModuleCoverage root #[problem "claimed" "LeanEval.Claimed"]).toBaseIO with
      | .ok _ => pure none
      | .error err => pure (some s!"expected success, got {err}")

  check "checkProblemModuleCoverage accepts a transitively imported module" passes fails do
    withFakeRepo
      #[("LeanEval/Claimed.lean", "import Mathlib\nimport LeanEval.Helper\n"),
        ("LeanEval/Helper.lean", "import Mathlib\n")] fun root => do
      match ← (checkProblemModuleCoverage root #[problem "claimed" "LeanEval.Claimed"]).toBaseIO with
      | .ok _ => pure none
      | .error err => pure (some s!"expected success, got {err}")

  check "checkProblemModuleCoverage rejects an unreached module" passes fails do
    withFakeRepo
      #[("LeanEval/Claimed.lean", "import Mathlib\n"),
        ("LeanEval/Nested/Orphan.lean", "import Mathlib\n")] fun root => do
      match ← (checkProblemModuleCoverage root #[problem "claimed" "LeanEval.Claimed"]).toBaseIO with
      | .ok _ => pure (some "expected rejection")
      | .error err =>
          let err := toString err
          pure <| (assertContains "err" err "LeanEval.Nested.Orphan").or
            (assertContains "err" err "LeanEval/Nested/Orphan.lean")

  check "checkProblemModuleCoverage rejects a manifest module with no source file" passes fails do
    withFakeRepo #[("LeanEval/Claimed.lean", "import Mathlib\n")] fun root => do
      match ← (checkProblemModuleCoverage root #[problem "claimed" "LeanEval.Clamied"]).toBaseIO with
      | .ok _ => pure (some "expected rejection")
      | .error err =>
          pure <| assertContains "err" (toString err) "LeanEval.Clamied"

  -- Regression for https://github.com/leanprover/lean-eval/pull/513: a manifest
  -- committed as `<id>.lean` was silently skipped, so its module never built.
  check "loadManifest rejects a non-toml manifest file" passes fails do
    withFakeRepo #[("manifests/problems/direct_summand.lean", "id = \"direct_summand\"\n")]
      fun root => do
        match ← (loadManifest root).toBaseIO with
        | .ok _ => pure (some "expected rejection")
        | .error err =>
            pure <| assertContains "err" (toString err) "is not a `.toml` file"

  check "loadManifest ignores .DS_Store" passes fails do
    withFakeRepo #[("manifests/problems/.DS_Store", "junk\n")] fun root => do
      match ← (loadManifest root).toBaseIO with
      | .ok entries => pure <| assertEq "entries" entries.size 0
      | .error err => pure (some s!"expected success, got {err}")

  -- The `@[eval_problem]` elaborator reads every `*.toml` in the directory,
  -- hidden or not. If `loadManifest` skipped hidden ones, a `.helper.toml`
  -- could satisfy the attribute for a tagged declaration that never enters the
  -- catalog, and the inventory cross-check would never look at its module.
  check "loadManifest does not skip a hidden toml manifest" passes fails do
    let hidden :=
      "id = \".helper\"\n" ++
      "title = \"Helper\"\n" ++
      "test = false\n" ++
      "module = \"LeanEval.Helper\"\n" ++
      "holes = [\"hole\"]\n" ++
      "submitter = \"tester\"\n"
    withFakeRepo #[("manifests/problems/.helper.toml", hidden)] fun root => do
      match ← (loadManifest root).toBaseIO with
      | .ok _ => pure (some "expected rejection")
      | .error err => pure <| assertContains "err" (toString err) "is invalid"

  -- A directory symlink would either duplicate a subtree under a second module
  -- prefix or, pointed at an ancestor, make the walk recurse forever.
  check "checkProblemModuleCoverage rejects a symlink in the source tree" passes fails do
    withFakeRepo #[("LeanEval/Claimed.lean", "import Mathlib\n")] fun root => do
      IO.FS.createDirAll (root / "Elsewhere")
      let _ ← IO.Process.run
        { cmd := "ln", args := #["-s", (root / "Elsewhere").toString,
                                 (root / "LeanEval" / "Linked").toString] }
      match ← (checkProblemModuleCoverage root #[problem "claimed" "LeanEval.Claimed"]).toBaseIO with
      | .ok _ => pure (some "expected rejection")
      | .error err => pure <| assertContains "err" (toString err) "symbolic link"

  let passCount ← passes.get
  let failCount ← fails.get
  IO.println s!"\n{passCount} passed, {failCount} failed."
  return if failCount == 0 then 0 else 1
