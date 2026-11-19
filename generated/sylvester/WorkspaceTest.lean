import Lean

open Lean

/-- Compare canonical paths on directory boundaries. -/
private def withinWorkspace (roots : Array System.FilePath) (path : System.FilePath) : Bool :=
  roots.any fun root => path == root ||
    path.toString.startsWith (root.toString ++ System.FilePath.pathSeparator.toString)

/-- Drop workspace/cache search directories, including relative paths and symlink aliases.
Nonexistent directories are omitted rather than allowing a build to create them later. -/
private def trustedSearchPath (roots : Array System.FilePath) (value : String) : IO String := do
  let mut dirs : System.SearchPath := []
  for dir in System.SearchPath.parse value do
    if dir.toString.isEmpty then continue
    try
      let dir ← IO.FS.realPath dir
      if !(withinWorkspace roots dir) && (← dir.isDir) then
        dirs := dirs ++ [dir]
    catch _ => pure ()
  return dirs.toString

/-- Use the executable supplied by the invoking Lake, outside writable build roots. -/
private def trustedTool (roots : Array System.FilePath) (tool : System.FilePath) :
    IO String := do
  let resolved ← IO.FS.realPath tool
  if withinWorkspace roots resolved then
    throw <| IO.userError s!"Tool must point outside the evaluation workspace and its writable cache: {resolved}"
  return resolved.toString

/-- Run the toolchain's comparator, enforcing bundled NanoDa as well as Lean.
Lake supplies LAKE, LEAN_SYSROOT, and LEAN_PATH to this trusted test driver.
Filter executable/library lookup before starting the outer supervisor; submission
elaboration belongs only inside comparator's sandboxes. -/
def main : IO UInt32 := do
  try
    let workspace ← IO.FS.realPath (← IO.currentDir)
    let roots := #[workspace, ← IO.FS.realPath (workspace / ".lake")]
    let path ← trustedSearchPath roots ((← IO.getEnv "PATH").getD "")
    if path.isEmpty then
      throw <| IO.userError "No trusted executable search directories remain"
    let mut env := #[("PATH", some path)]
    for envName in #["LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH"] do
      if let some value ← IO.getEnv envName then
        let value ← trustedSearchPath roots value
        env := env.push (envName, if value.isEmpty then none else some value)
    let some lake ← IO.getEnv "LAKE"
      | throw <| IO.userError "Run this driver with `lake test` (LAKE is missing)."
    let some sysroot ← IO.getEnv "LEAN_SYSROOT"
      | throw <| IO.userError "Run this driver with `lake test` (LEAN_SYSROOT is missing)."
    let lake ← trustedTool roots lake
    let nanoda ← trustedTool roots ((System.FilePath.mk sysroot) / "bin" / "nanoda_bin")
    let configText ← IO.FS.readFile "config.json"
    let config ← IO.ofExcept (Json.parse configText)
    let config := config.setObjVal! "enable_nanoda" (Json.bool false)
    let config := config.setObjVal! "external_kernels"
      (Json.mkObj [("nanoda", Json.arr #[Json.str nanoda])])
    IO.FS.withTempFile fun handle enforcedPath => do
      handle.putStr config.pretty
      handle.flush
      let child ← IO.Process.spawn {
        cmd := lake
        args := #["comparator", "--config", enforcedPath.toString]
        env
      }
      child.wait
  catch err =>
    IO.eprintln "Failed to run `lake comparator`."
    IO.eprintln "Install the pinned Lean toolchain and bubblewrap; run this workspace with `lake test`."
    IO.eprintln s!"Original error: {err}"
    pure 2
