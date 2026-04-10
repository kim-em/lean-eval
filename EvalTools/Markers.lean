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
  theoremName : String
  author : String
  notes : Option String := none
  source : Option String := none
  informalSolution : Option String := none

def manifestRelativePath : System.FilePath :=
  "manifests" / "problems.toml"

partial def findManifestPath? (dir : System.FilePath) : IO (Option System.FilePath) := do
  let candidate := dir / manifestRelativePath
  if ← candidate.pathExists then
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
    let theoremName ← requireNonempty "theorem" (← t.decode `theorem)
    let author ← requireNonempty "author" (← t.decode `author)
    let notes? : Option String ← t.decode? `notes
    let source? : Option String ← t.decode? `source
    let informalSolution? : Option String ← t.decode? `informal_solution
    return {
      id := id
      title := title
      test := ← t.decode `test
      moduleName := moduleName
      theoremName := theoremName
      author := author
      notes := notes?.bind fun s => if s.isEmpty then none else some s
      source := source?.bind fun s => if s.isEmpty then none else some s
      informalSolution := informalSolution?.bind fun s => if s.isEmpty then none else some s
    }

def decodeErrorsToString (errors : Array DecodeError) : String :=
  "\n".intercalate <| errors.toList.map fun err => err.msg

def parseManifestMetadata (contents : String) (fileName : String := manifestRelativePath.toString) :
    IO (Except String (Array EvalProblemMetadata)) := do
  let inputCtx := mkInputContext contents fileName
  let table ←
    match (← Lake.Toml.loadToml inputCtx |>.toBaseIO) with
    | Except.ok table => pure table
    | Except.error err => return Except.error (← Lake.mkMessageLogString err)
  let decoded :
      EStateM.Result Unit (Array DecodeError) (Array EvalProblemMetadata) :=
    (Lake.Toml.Table.decode (α := Array EvalProblemMetadata) table `problem).run #[]
  let blocks ←
    match decoded with
    | EStateM.Result.ok entries errors =>
        if errors.isEmpty then
          pure entries
        else
          return Except.error (decodeErrorsToString errors)
    | EStateM.Result.error _ errors =>
        return Except.error (decodeErrorsToString errors)
  let mut entries : Array EvalProblemMetadata := #[]
  let mut seenIds : HashSet String := {}
  let mut seenRefs : HashSet (String × String) := {}
  for metadata in blocks do
    if seenIds.contains metadata.id then
      return Except.error s!"Duplicate problem id `{metadata.id}` in `manifests/problems.toml`."
    seenIds := seenIds.insert metadata.id
    let theoremKey := (metadata.moduleName, metadata.theoremName)
    if seenRefs.contains theoremKey then
      return Except.error
        s!"Duplicate theorem reference `{metadata.moduleName}:{metadata.theoremName}` in `manifests/problems.toml`."
    seenRefs := seenRefs.insert theoremKey
    entries := entries.push metadata
  return Except.ok entries

def moduleNameForDecl (env : Environment) (declName : Name) : String :=
  match env.getModuleIdxFor? declName with
  | some idx => toString <| env.header.moduleNames[idx.toNat]!
  | none => toString env.mainModule

def theoremMatches (declName : Name) (theoremField : String) : Bool :=
  theoremField == declName.toString || theoremField == declName.getString!

def validateMatchingManifestEntry
    (declName : Name) (entries : Array EvalProblemMetadata) (moduleName : String) :
    Except String EvalProblemMetadata := do
  let matchingEntries := entries.filter fun entry =>
    entry.moduleName == moduleName && theoremMatches declName entry.theoremName
  if matchingEntries.isEmpty then
    throw
      s!"The theorem `{declName}` is marked with @[eval_problem], but `manifests/problems.toml` has no matching `theorem = ...` entry.\nAdd a corresponding problem entry to the manifest."
  if matchingEntries.size > 1 then
    throw
      s!"The theorem `{declName}` is marked with @[eval_problem], but `manifests/problems.toml` has multiple matching entries in module `{moduleName}`."
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
      s!"- theorem: `{metadata.theoremName}`",
      s!"- author: {metadata.author}"
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
    docString? := some (formatManifestHover metadata)
    explicit := true
  }
  Elab.pushInfoLeaf info

def ensureEvalProblemManifestEntry (declName : Name) : AttrM EvalProblemMetadata := do
  let env ← getEnv
  match env.find? declName with
  | some (.thmInfo _) | some (.opaqueInfo _) => pure ()
  | _ =>
      throwError
        "The attribute @[eval_problem] may only be applied to theorem or opaque theorem declarations, but `{declName}` is not one."
  let cwd ← IO.currentDir
  let some manifestPath ← findManifestPath? cwd
    | throwError
        "Could not find `manifests/problems.toml` while validating @[eval_problem] on `{declName}`."
  let manifestContents ← IO.FS.readFile manifestPath
  let entries ←
    match ← parseManifestMetadata manifestContents manifestPath.toString with
    | .ok entries => pure entries
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
