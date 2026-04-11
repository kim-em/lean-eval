import Lean
import Lean.DeclarationRange

open Lean

structure SourceRange where
  startLine : Nat
  startColumn : Nat
  endLine : Nat
  endColumn : Nat
  deriving ToJson

structure ExtractedTheorem where
  declarationName : String
  module : String
  sourceRange : SourceRange
  deriving ToJson

def parseName (text : String) : Name :=
  text.splitOn "." |>.foldl Name.str .anonymous

def lastComponent? : Name → Option String
  | .str _ s => some s
  | .num p _ => lastComponent? p
  | .anonymous => none

def findDeclByBasename (env : Environment) (moduleName declName : Name) : IO Name := do
  let some moduleIdx := env.getModuleIdx? moduleName
    | throw <| IO.userError s!"Module '{moduleName}' is not present in the imported environment."
  let targetBasename := lastComponent? declName
  let mut foundNames := (#[] : Array Name)
  for (candidate, _) in env.constants do
    if env.getModuleIdxFor? candidate == some moduleIdx && lastComponent? candidate == targetBasename then
      foundNames := foundNames.push candidate
  match foundNames.size with
  | 1 => return foundNames[0]!
  | 0 => throw <| IO.userError s!"Declaration '{declName}' was not found in module '{moduleName}'."
  | _ => throw <| IO.userError s!"Declaration '{declName}' is ambiguous in module '{moduleName}'."

def resolveDeclName (env : Environment) (moduleName declName : Name) : IO Name := do
  let candidates :=
    if declName.isAnonymous then
      #[moduleName]
    else if declName == moduleName || moduleName.isPrefixOf declName then
      #[declName]
    else
      #[declName, moduleName ++ declName]
  for candidate in candidates do
    if env.find? candidate |>.isSome then
      return candidate
  findDeclByBasename env moduleName declName

def extractTheorem (moduleNameText declNameText : String) : IO ExtractedTheorem := do
  let moduleName := parseName moduleNameText
  let declName := parseName declNameText
  initSearchPath (← findSysroot)
  let env ← importModules #[{ module := moduleName }] {}
  let resolvedDeclName ← resolveDeclName env moduleName declName
  let some constantInfo := env.find? resolvedDeclName
    | throw <| IO.userError s!"Resolved declaration '{resolvedDeclName}' disappeared unexpectedly."
  let some declRanges ← ({ env := env } : PPContext).runCoreM do
    findDeclarationRanges? resolvedDeclName
    | throw <| IO.userError s!"Declaration ranges for '{resolvedDeclName}' were not available."
  let sourceRange : SourceRange := {
    startLine := declRanges.range.pos.line
    startColumn := declRanges.range.pos.column
    endLine := declRanges.range.endPos.line
    endColumn := declRanges.range.endPos.column
  }
  match constantInfo with
  | .thmInfo _ | .opaqueInfo _ =>
      return {
        declarationName := toString resolvedDeclName
        module := moduleNameText
        sourceRange := sourceRange
      }
  | _ =>
      throw <| IO.userError s!"Declaration '{resolvedDeclName}' is not a theorem or opaque theorem."

def main (args : List String) : IO UInt32 := do
  let [moduleName, declName] := args
    | throw <| IO.userError "usage: extract_theorem <module> <declaration>"
  let result ← extractTheorem moduleName declName
  IO.println <| Json.compress <| toJson result
  return 0
