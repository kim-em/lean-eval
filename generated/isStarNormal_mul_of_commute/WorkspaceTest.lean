import Lean

open Lean

def comparatorExists (comparatorBin : String) : IO Bool := do
  if comparatorBin.contains '/' then
    return (← System.FilePath.pathExists comparatorBin)
  try
    let child ← IO.Process.spawn {
      cmd := "sh"
      args := #["-c", "command -v \"$1\" >/dev/null 2>&1", "sh", comparatorBin]
    }
    let exitCode ← child.wait
    return exitCode == 0
  catch _ =>
    return false

def main : IO UInt32 := do
  let comparatorBin := (← IO.getEnv "COMPARATOR_BIN").getD "comparator"
  if !(← comparatorExists comparatorBin) then
    IO.eprintln s!"Failed to run comparator via `{comparatorBin}`."
    IO.eprintln "Make sure `comparator` is installed and on your `PATH`, or set `COMPARATOR_BIN=/path/to/comparator`."
    IO.eprintln "See the root repository README for comparator setup details, including landrun and lean4export."
    pure 1
  else
    try
      let child ← IO.Process.spawn {
        cmd := "lake"
        args := #["env", comparatorBin, "config.json"]
      }
      let exitCode ← child.wait
      pure exitCode
    catch err =>
      IO.eprintln s!"Failed to run comparator via `{comparatorBin}`."
      IO.eprintln "Make sure `comparator` is installed and on your `PATH`, or set `COMPARATOR_BIN=/path/to/comparator`."
      IO.eprintln "See the root repository README for comparator setup details, including landrun and lean4export."
      IO.eprintln s!"Original error: {err}"
      pure 1
