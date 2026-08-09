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
  /-- Names of the explicit parameters bound by the declaration's *signature*,
  in application order, or `none` when they could not be determined. This
  includes source-level `variable` parameters exactly when Lean actually
  retained them in the declaration, and excludes binders that belong to the
  statement itself (a leading `∀` in the conclusion), which the generated
  delegation must not apply. -/
  explicitParameters : Option (Array String)
  /-- Names of declarations from the same module that appear (transitively) in the
  type or value of this theorem. Computed from the elaborated terms, so this captures
  uses introduced by typeclass synthesis (which the `.ilean` references metadata
  records as textual matches only). -/
  sameModuleDependencies : Array String
  /-- One of `"theorem"` (covers `.thmInfo` and `.opaqueInfo`), `"def"`, or
  `"instance"`. Drives whether the generator emits this hole in `theorem_names`
  or `definition_names` in the comparator config. -/
  kind : String
  deriving ToJson

/-- The number of leading `fun` binders of `value`, if what they wrap is a bare
`sorry`; `none` for any other body. -/
def sorryBodyArity : Expr → Option Nat
  | .lam _ _ body _ => (sorryBodyArity body).map (· + 1)
  | e => if e.isSorry then some 0 else none

/-- Names of the explicit parameters bound by the declaration's signature, in
application order, or `none` when they cannot be determined.

An eval-problem hole has a bare `sorry` body, so its elaborated value is one
`fun` binder per signature binder — the declaration's own binders together with
the `variable` binders Lean retained — wrapped around `sorryAx`. Counting those
lambdas separates the signature from the statement: a conclusion that starts
with `∀` contributes `forallE` binders to the type but no lambda to the value,
and applying those in the generated delegation would be wrong.

The `sorry` body is what makes the count meaningful, so it is checked rather
than assumed. The check is necessary but not sufficient: `by intro x; sorry`
also elaborates to a lambda over `sorryAx`, and only the source text says
whether the body was a bare `sorry`. The generator decides that, and asks for
this list only when it was. -/
def signatureExplicitParameters (info : ConstantInfo) : Option (Array String) := do
  let arity ← info.value? (allowOpaque := true) >>= sorryBodyArity
  return Id.run do
    let mut remaining := arity
    let mut type := info.type
    let mut names : Array String := #[]
    while remaining > 0 do
      match type with
      | .forallE name _ body binderInfo =>
          if binderInfo == .default && !name.isAnonymous then
            names := names.push name.toString
          type := body
          remaining := remaining - 1
      | _ => remaining := 0
    return names

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

/-- Last components of the coercion type classes. A coercion (`↑`/`⇑`) is
unfolded during elaboration, so the instance backing it never appears in the
elaborated term's `getUsedConstantsAsSet` — even when a kept helper's *source
text* relies on it (e.g. `T x` where `instCoeFun … : CoeFun …`). The generated
`ChallengeDeps.lean` reproduces source text, so it must carry these instances;
we recover them structurally rather than from the dependency closure. -/
def coercionClassLastComponents : Array String :=
  #["Coe", "CoeTC", "CoeHead", "CoeTail", "CoeHTCT", "CoeHTC", "CoeOut",
    "CoeDep", "CoeT", "CoeFun", "CoeSort"]

def isCoercionClassName (n : Name) : Bool :=
  match lastComponent? n with
  | some s => coercionClassLastComponents.contains s
  | none => false

/-- The head constant of a (possibly dependent) type's conclusion: strip leading
`∀`/`→` binders and return the application head. -/
partial def conclusionHead : Expr → Option Name
  | .forallE _ _ body _ => conclusionHead body
  | e => e.getAppFn.constName?

/-- Compute the set of names of declarations in `moduleName` that are reachable from
the type or value of `start`, following the same-module subgraph of the constant
dependency relation. The starting declaration itself is excluded from the result.

Internal compiler-generated auxiliaries (`._proof_1`, `._eq_1`, `.match_1`, …)
are traversed through — so genuine helpers they reference are still found — but
excluded from the returned set: they have no user source span to extract and are
regenerated automatically when their parent declaration is re-elaborated. (A
`noncomputable def` over a `Finset` sum, for instance, emits a `._proof_1` whose
prefix would otherwise be mistaken for a helper namespace to `open`.)

Coercion instances (see `coercionClassLastComponents`) are pulled in separately
via `coeCandidates`: once the closure contains a constant, any candidate whose
type mentions that constant is added (and re-closed over). Such instances vanish
from elaborated terms but are still needed by the source text the generator
re-emits. `coeCandidates` pairs each candidate with the constants appearing in
its type, and is gathered (and source-order filtered) by the caller. -/
def collectSameModuleDependencies (env : Environment) (moduleName start : Name)
    (coeCandidates : Array (Name × Array Name)) : Array Name := Id.run do
  let some moduleIdx := env.getModuleIdx? moduleName | return #[]
  let mut closure : NameSet := {}
  let mut stack : Array Name := #[start]
  let mut progress := true
  while progress do
    progress := false
    -- Direct dependency closure over the same-module subgraph.
    while !stack.isEmpty do
      let current := stack.back!
      stack := stack.pop
      if closure.contains current then continue
      closure := closure.insert current
      let some info := env.find? current | continue
      for c in info.getUsedConstantsAsSet do
        if env.getModuleIdxFor? c == some moduleIdx
            && c != current && !closure.contains c then
          stack := stack.push c
    -- Pull in coercion candidates now reachable, then re-close.
    for (inst, typeConsts) in coeCandidates do
      if closure.contains inst then continue
      if typeConsts.any closure.contains then
        stack := stack.push inst
        progress := true
  return (closure.erase start).toArray.filter (fun n => !n.isInternalDetail)

/-- Gather the same-module coercion providers (see `coercionClassLastComponents`)
that are declared *before* `beforeLine`, paired with the constants in their type.

Restricting to declarations preceding the extracted hole matches Lean scoping: a
coercion used by a kept helper must be declared before that helper, hence before
the hole. It also prevents leaking declarations that follow the hole into
`ChallengeDeps.lean`. Detected structurally by the conclusion head of the type —
`Lean.Meta.isInstanceCore` is unreliable against the bare environment produced by
`importModules` (the instance extension state is not materialised). -/
def gatherCoercionCandidates (env : Environment) (moduleName : Name) (beforeLine : Nat) :
    CoreM (Array (Name × Array Name)) := do
  let some moduleIdx := env.getModuleIdx? moduleName | return #[]
  let mut cands : Array (Name × Array Name) := #[]
  for (c, info) in env.constants do
    if env.getModuleIdxFor? c == some moduleIdx then
      if let some cls := conclusionHead info.type then
        if isCoercionClassName cls then
          if let some r ← findDeclarationRanges? c then
            if r.range.pos.line < beforeLine then
              cands := cands.push (c, info.type.getUsedConstants)
  return cands

def extractTheorem (moduleNameText declNameText : String) : IO ExtractedTheorem := do
  let moduleName := parseName moduleNameText
  let declName := parseName declNameText
  initSearchPath (← findSysroot)
  let env ← importModules #[{ module := moduleName }] {}
  let resolvedDeclName ← resolveDeclName env moduleName declName
  let some constantInfo := env.find? resolvedDeclName
    | throw <| IO.userError s!"Resolved declaration '{resolvedDeclName}' disappeared unexpectedly."
  let (declRanges?, coeCandidates) ← ({ env := env } : PPContext).runCoreM do
    let declRanges? ← findDeclarationRanges? resolvedDeclName
    let coeCandidates ← match declRanges? with
      | some r => gatherCoercionCandidates env moduleName r.range.pos.line
      | none => pure #[]
    return (declRanges?, coeCandidates)
  let some declRanges := declRanges?
    | throw <| IO.userError s!"Declaration ranges for '{resolvedDeclName}' were not available."
  let sourceRange : SourceRange := {
    startLine := declRanges.range.pos.line
    startColumn := declRanges.range.pos.column
    endLine := declRanges.range.endPos.line
    endColumn := declRanges.range.endPos.column
  }
  let kind? : Option String := match constantInfo with
    | .thmInfo _ | .opaqueInfo _ => some "theorem"
    | .defnInfo _ =>
        if Lean.Meta.isInstanceCore env resolvedDeclName then some "instance" else some "def"
    | _ => none
  match kind? with
  | some kind =>
      let deps := collectSameModuleDependencies env moduleName resolvedDeclName coeCandidates
      return {
        declarationName := toString resolvedDeclName
        module := moduleNameText
        sourceRange := sourceRange
        explicitParameters := signatureExplicitParameters constantInfo
        sameModuleDependencies := deps.map toString
        kind := kind
      }
  | none =>
      throw <| IO.userError
        s!"Declaration '{resolvedDeclName}' has unsupported kind for an eval-problem hole."

def main (args : List String) : IO UInt32 := do
  let [moduleName, declName] := args
    | throw <| IO.userError "usage: extract_theorem <module> <declaration>"
  let result ← extractTheorem moduleName declName
  IO.println <| Json.compress <| toJson result
  return 0
