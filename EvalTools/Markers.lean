import Lake.Toml
import Lake.Util.Message
import Lean

open Lean
open Lean.Parser
open Lake
open Lake.Toml
open Std

set_option autoImplicit false

namespace EvalTools

structure EvalProblemMetadata where
  id : String
  title : String
  test : Bool
  moduleName : String
  /-- The names of the `@[eval_problem]`-tagged declarations in `moduleName` that
  comprise this problem; comparator's `theorem_names` and `definition_names`
  are derived from this list (split by declaration kind). At least one entry
  is required. -/
  holes : Array String
  submitter : String
  notes : Option String := none
  source : Option String := none
  informalSolution : Option String := none

/-- The manifest directory, relative to the repository root. Each problem
lives in its own file `manifests/problems/<id>.toml` with top-level keys. -/
def manifestRelativePath : System.FilePath :=
  "manifests" / "problems"

/-- Read a manifest `module` field as a module name: every `.` separates
components, so `LeanEval.Foo.Bar` is `LeanEval/Foo/Bar.lean` and never
`LeanEval/Foo.Bar.lean`. The inventory and extractor executables resolve the
same field the same way; the two must agree or they address different files. -/
def parseModuleName (text : String) : Name :=
  text.splitOn "." |>.foldl Name.str .anonymous

/-- Walk up from `dir` searching for the manifest directory
`manifests/problems/`. Returns the directory itself if found. -/
partial def findManifestPath? (dir : System.FilePath) : IO (Option System.FilePath) := do
  let candidate := dir / manifestRelativePath
  if ← candidate.isDir then
    return some candidate
  match dir.parent with
  | none => return none
  | some parent =>
      if parent == dir then
        return none
      findManifestPath? parent

def requireNonempty (field value : String) : EDecodeM String := do
  if value.isEmpty then
    throwDecodeErrorAt Syntax.missing s!"Manifest field `{field}` must be non-empty."
  pure value

instance : DecodeToml EvalProblemMetadata where
  decode v := do
    let t ← v.decodeTable
    let id ← requireNonempty "id" (← t.decode `id)
    let title ← requireNonempty "title" (← t.decode `title)
    let moduleName ← requireNonempty "module" (← t.decode `module)
    let holes : Array String ← t.decode `holes
    if holes.isEmpty then
      throwDecodeErrorAt Syntax.missing
        s!"Manifest entry `{id}` has empty `holes` array; list at least one declaration."
    for h in holes do
      if h.isEmpty then
        throwDecodeErrorAt Syntax.missing
          s!"Manifest entry `{id}` has an empty string in `holes`."
    let submitter ← requireNonempty "submitter" (← t.decode `submitter)
    let notes? : Option String ← t.decode? `notes
    let source? : Option String ← t.decode? `source
    let informalSolution? : Option String ← t.decode? `informal_solution
    return {
      id := id
      title := title
      test := ← t.decode `test
      moduleName := moduleName
      holes := holes
      submitter := submitter
      notes := notes?.bind fun s => if s.isEmpty then none else some s
      source := source?.bind fun s => if s.isEmpty then none else some s
      informalSolution := informalSolution?.bind fun s => if s.isEmpty then none else some s
    }

def decodeErrorsToString (errors : Array DecodeError) : String :=
  "\n".intercalate <| errors.toList.map fun err => err.msg

/-- Parse a single per-problem TOML file (top-level keys: `id`, `title`,
`test`, `module`, `holes`, `submitter`, optional `notes`, `source`,
`informal_solution`). The caller is responsible for `id ↔ filename` and
cross-file uniqueness checks (see `EvalTools.loadManifest`). -/
def parseManifestEntry (contents : String) (fileName : String) :
    IO (Except String EvalProblemMetadata) := do
  let inputCtx := mkInputContext contents fileName
  let table ←
    match (← Lake.Toml.loadToml inputCtx |>.toBaseIO) with
    | Except.ok table => pure table
    | Except.error err => return Except.error (← Lake.mkMessageLogString err)
  let decoded :
      EStateM.Result Unit (Array DecodeError) EvalProblemMetadata :=
    (DecodeToml.decode (α := EvalProblemMetadata) (Lake.Toml.Value.table Syntax.missing table)).run #[]
  match decoded with
  | EStateM.Result.ok entry errors =>
      if errors.isEmpty then
        return Except.ok entry
      else
        return Except.error (decodeErrorsToString errors)
  | EStateM.Result.error _ errors =>
      return Except.error (decodeErrorsToString errors)

def moduleNameForDecl (env : Environment) (declName : Name) : String :=
  match env.getModuleIdxFor? declName with
  | some idx => toString <| env.header.moduleNames[idx.toNat]!
  | none => toString env.mainModule

def holeMatches (declName : Name) (holeField : String) : Bool :=
  holeField == declName.toString || holeField == declName.getString!

def validateMatchingManifestEntry
    (declName : Name) (entries : Array EvalProblemMetadata) (moduleName : String) :
    Except String EvalProblemMetadata := do
  let matchingEntries := entries.filter fun entry =>
    entry.moduleName == moduleName && entry.holes.any (holeMatches declName ·)
  if matchingEntries.isEmpty then
    throw
      s!"The declaration `{declName}` is marked with @[eval_problem], but no file in `manifests/problems/` lists it in `holes`.\nAdd a corresponding `manifests/problems/<id>.toml` file."
  if matchingEntries.size > 1 then
    throw
      s!"The declaration `{declName}` is marked with @[eval_problem], but `manifests/problems/` has multiple matching entries in module `{moduleName}`."
  match matchingEntries[0]? with
  | some metadata => return metadata
  | none => throw "internal error: missing manifest entry after nonempty match set"

def formatManifestHover (metadata : EvalProblemMetadata) : String :=
  Id.run do
    let mut lines := #[
      "Benchmark problem metadata.",
      "",
      s!"- id: `{metadata.id}`",
      s!"- title: {metadata.title}",
      s!"- test: `{metadata.test}`",
      s!"- module: `{metadata.moduleName}`",
      s!"- holes: {", ".intercalate (metadata.holes.toList.map (s!"`{·}`"))}",
      s!"- submitter: {metadata.submitter}"
    ]
    if let some notes := metadata.notes then
      lines := lines.push s!"- notes: {notes}"
    if let some source := metadata.source then
      lines := lines.push s!"- source: {source}"
    if let some informalSolution := metadata.informalSolution then
      lines := lines.push s!"- informal_solution: {informalSolution}"
    "\n".intercalate lines.toList

def mkEvalProblemExpr (env : Environment) (declName : Name) : Expr :=
  match env.find? declName with
  | some info => .const declName (info.levelParams.map Level.param)
  | none => .const declName []

def pushEvalProblemHoverInfo (declName : Name) (attrStx : Syntax) (metadata : EvalProblemMetadata) :
    AttrM Unit := do
  let tokenStx := attrStx[0]
  let env ← getEnv
  let info : Elab.Info := .ofDelabTermInfo {
    toTermInfo := {
      elaborator := `eval_problem
      stx := tokenStx
      lctx := {}
      expectedType? := none
      expr := mkEvalProblemExpr env declName
      isBinder := false
      isDisplayableTerm := false
    }
    mkDocString? := some (fun _ => pure (formatManifestHover metadata))
    explicit := true
  }
  Elab.pushInfoLeaf info

def binderInfoDescription (binderInfo : BinderInfo) : String :=
  match binderInfo with
  | .default => "explicit"
  | .implicit => "implicit"
  | .strictImplicit => "strict implicit"
  | .instImplicit => "instance implicit"

structure TheoremBinder where
  name : Name
  type : Expr
  binderInfo : BinderInfo
  fvar : Expr

partial def collectTheoremBinders (type : Expr) : MetaM (Array TheoremBinder × Expr) := do
  let rec go (type : Expr) (acc : Array TheoremBinder) : MetaM (Array TheoremBinder × Expr) := do
    match type.consumeMData with
    | .forallE binderName binderType body binderInfo =>
        let binderType ← Meta.whnfD binderType
        Meta.withLocalDecl binderName binderInfo binderType fun localDecl => do
          let acc := acc.push {
            name := binderName
            type := binderType
            binderInfo := binderInfo
            fvar := localDecl
          }
          go (body.instantiate1 localDecl) acc
    | _ => pure (acc, type)
  go type #[]

def exprDependsOnFVar (expr fvar : Expr) : Bool :=
  (expr.find? fun subexpr => subexpr == fvar).isSome

def collectForbiddenImplicitBinders (type : Expr) : MetaM (Array (Name × Expr × BinderInfo)) := do
  let (binders, resultType) ← collectTheoremBinders type
  let explicitBinderTypes :=
    binders.foldl (init := #[]) fun acc binder =>
      if binder.binderInfo == .default then
        acc.push binder.type
      else
        acc
  let forbidden := binders.filterMap fun binder =>
    if binder.binderInfo != .implicit && binder.binderInfo != .strictImplicit then
      none
    else if binder.type.isSort then
      none
    else
      let inferable :=
        explicitBinderTypes.any (fun explicitType => exprDependsOnFVar explicitType binder.fvar) ||
        exprDependsOnFVar resultType binder.fvar
      if inferable then
        none
      else
        some (binder.name, binder.type, binder.binderInfo)
  pure forbidden

def validateEvalProblemBinders (declName : Name) (type : Expr) : AttrM Unit := do
  let forbiddenBinders ←
    ({ env := ← getEnv, opts := ← getOptions } : PPContext).runMetaM do
      collectForbiddenImplicitBinders type
  if forbiddenBinders.isEmpty then
    return
  let binderLines ←
    ({ env := ← getEnv, opts := ← getOptions } : PPContext).runMetaM do
      forbiddenBinders.mapM fun (binderName, binderType, binderInfo) => do
        let binderTypeFmt ← Meta.ppExpr binderType
        let binderName :=
          if binderName == Name.anonymous then "_" else binderName.toString
        pure s!"- `{binderName}` : {binderTypeFmt} ({binderInfoDescription binderInfo})"
  let details := "\n".intercalate binderLines.toList
  throwError
    "{String.intercalate "\n"
      [s!"The theorem `{declName}` uses implicit value parameters that are not inferable from the explicit hypotheses or the conclusion, which @[eval_problem] does not allow."
      , "Generated benchmark wrappers must be able to call the theorem by ordinary application, without named arguments or `@`."
      , "Keep implicit type parameters like `{α : Type*}` and instance parameters like `[Field K]`."
      , "For benchmark inputs that are not recoverable from later explicit binders, use explicit binders `(x : τ)` instead of implicit ones `{x : τ}`."
      , s!"Non-inferable implicit binders:\n{details}"]}"

def ensureEvalProblemManifestEntry (declName : Name) : AttrM EvalProblemMetadata := do
  let env ← getEnv
  match env.find? declName with
  | some (.thmInfo info) =>
      validateEvalProblemBinders declName info.type
  | some (.opaqueInfo info) =>
      validateEvalProblemBinders declName info.type
  | some (.defnInfo _) =>
      -- Definition / instance holes: comparator only checks name, type, universe
      -- levels, and safety of the hole, so the binder-shape restriction we
      -- impose on theorems (so they can be applied positionally) does not apply.
      pure ()
  | _ =>
      throwError
        "The attribute @[eval_problem] may only be applied to theorem, opaque, def, or instance declarations, but `{declName}` is not one."
  let cwd ← IO.currentDir
  let some manifestDir ← findManifestPath? cwd
    | throwError
        "Could not find `manifests/problems/` while validating @[eval_problem] on `{declName}`."
  let mut entries : Array EvalProblemMetadata := #[]
  for entry in (← manifestDir.readDir) do
    if entry.path.extension == some "toml" then
      let contents ← IO.FS.readFile entry.path
      match ← parseManifestEntry contents entry.path.toString with
      | .ok m => entries := entries.push m
      | .error err => throwError "{err}"
  let moduleName := moduleNameForDecl env declName
  match validateMatchingManifestEntry declName entries moduleName with
  | .ok metadata => pure metadata
  | .error err => throwError "{err}"

initialize evalProblemExt : PersistentEnvExtension Name Name NameSet ←
  registerPersistentEnvExtension {
    name := `EvalTools.evalProblemExt
    mkInitial := pure {}
    addImportedFn := fun _ _ => pure {}
    addEntryFn := fun (s : NameSet) n => s.insert n
    exportEntriesFnEx := fun env es =>
      let entries : Array Name := es.foldl (fun acc entry => acc.push entry) #[]
      let entries := entries.filter (env.contains (skipRealize := false))
      .uniform <| entries.qsort Name.quickLt
    statsFn := fun s => "eval_problem attribute" ++ Format.line ++ "number of local entries: " ++ format s.size
    asyncMode := .mainOnly
    replay? := some fun _ newState newConsts s =>
      newConsts.foldl (init := s) fun acc c =>
        if newState.contains c then acc.insert c else acc
  }

initialize evalProblemAttr : AttributeImpl ←
  let attrImpl : AttributeImpl := {
    ref := `eval_problem
    name := `eval_problem
    descr := "Marks theorem declarations as benchmark problems and validates their manifest metadata."
    applicationTime := AttributeApplicationTime.afterTypeChecking
    add := fun decl stx kind => do
      Attribute.Builtin.ensureNoArgs stx
      unless kind == AttributeKind.global do
        throwAttrMustBeGlobal `eval_problem kind
      let env ← getEnv
      unless (env.getModuleIdxFor? decl).isNone do
        throwAttrDeclInImportedModule `eval_problem decl
      unless evalProblemExt.toEnvExtension.asyncMayModify env decl do
        throwAttrNotInAsyncCtx `eval_problem decl env.asyncPrefix?
      let metadata ← ensureEvalProblemManifestEntry decl
      pushEvalProblemHoverInfo decl stx metadata
      modifyEnv fun env => evalProblemExt.addEntry (asyncDecl := decl) env decl
  }
  registerBuiltinAttribute attrImpl
  pure attrImpl

def hasEvalProblemTag (env : Environment) (declName : Name) : Bool :=
  match env.getModuleIdxFor? declName with
  | some modIdx => (evalProblemExt.getModuleEntries env modIdx).binSearchContains declName Name.quickLt
  | none => (evalProblemExt.getState (asyncDecl := declName) env).contains declName

end EvalTools
