import Lean

open Lean

/-- Invoke comparator on this workspace, forcing the external nanoda kernel on.

nanoda is a global requirement of the eval, not a per-problem option: every
solution must be accepted by comparator **and** replayed through nanoda's
independent kernel. Rather than encode that in each workspace's `config.json`,
this harness reads the committed config, overrides `enable_nanoda := true`, and
hands the result to comparator — so nanoda runs regardless of what the file on
disk says. This mirrors the comparator-live "gold standard" setup, which forces
nanoda at the invocation site and leaves project configs untouched. -/
def main : IO UInt32 := do
  let comparatorBin := (← IO.getEnv "COMPARATOR_BIN").getD "comparator"
  try
    let configText ← IO.FS.readFile "config.json"
    let config ← IO.ofExcept (Json.parse configText)
    let config := config.setObjVal! "enable_nanoda" (Json.bool true)
    IO.FS.withTempFile fun handle enforcedPath => do
      handle.putStr config.pretty
      handle.flush
      let child ← IO.Process.spawn {
        cmd := "lake"
        args := #["env", comparatorBin, enforcedPath.toString]
      }
      child.wait
  catch err =>
    IO.eprintln s!"Failed to run comparator via `{comparatorBin}`."
    IO.eprintln "Make sure `comparator` and the `nanoda_bin` external kernel are installed and on your `PATH`, or set `COMPARATOR_BIN=/path/to/comparator`."
    IO.eprintln "See the root repository README for comparator setup details, including landrun, lean4export, and nanoda."
    IO.eprintln s!"Original error: {err}"
    pure 1
