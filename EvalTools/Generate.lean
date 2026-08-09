import Lake.Toml
import Lake.Util.Message
import Lean
import EvalTools.Manifest
import EvalTools.Markers
import EvalTools.Subprocess

set_option linter.deprecated false

open Lean
open Lean.Parser
open Lake
open Lake.Toml

namespace EvalTools

set_option autoImplicit false

/-! ## Constants -/

def fixedAxioms : Array String :=
  #["propext", "Quot.sound", "Classical.choice"]

def expectedFiles : Array String := #[
  "README.md",
  "lean-toolchain",
  "lakefile.toml",
  "ChallengeDeps.lean",
  "Challenge.lean",
  "Solution.lean",
  "Submission.lean",
  "Submission/Helpers.lean",
  "WorkspaceTest.lean",
  "config.json",
  "holes.json"
]

def ignoredPathNames : Array String := #[".lake", "build", ".cache", "lake-manifest.json"]

/-! ## Workspace test template -/

def loadWorkspaceTestTemplate (root : System.FilePath) : IO String :=
  IO.FS.readFile (root / "templates" / "WorkspaceTest.lean")

/-! ## Mathlib dependency -/

structure DependencySpec where
  name : String
  git : String
  rev : String
  deriving Inhabited

private structure RawRequire where
  name : String
  git : Option String := none
  rev : Option String := none
  deriving Inhabited

private instance : DecodeToml RawRequire where
  decode v := do
    let t ← v.decodeTable
    let name : String ← t.decode `name
    let git? : Option String ← t.decode? `git
    let rev? : Option String ← t.decode? `rev
    return { name := name, git := git?, rev := rev? }

def loadRootMathlibDependency (root : System.FilePath) : IO DependencySpec := do
  let path := root / "lakefile.toml"
  let contents ← IO.FS.readFile path
  let inputCtx := mkInputContext contents path.toString
  let table ←
    match (← Lake.Toml.loadToml inputCtx |>.toBaseIO) with
    | .ok table => pure table
    | .error err => throw <| IO.userError (← Lake.mkMessageLogString err)
  let decoded :
      EStateM.Result Unit (Array DecodeError) (Array RawRequire) :=
    (Lake.Toml.Table.decode (α := Array RawRequire) table `require).run #[]
  let requires ←
    match decoded with
    | .ok arr errors =>
        if errors.isEmpty then pure arr
        else throw <| IO.userError (decodeErrorsToString errors)
    | .error _ errors =>
        throw <| IO.userError (decodeErrorsToString errors)
  let mathlib := requires.filter fun r => r.name == "mathlib"
  if mathlib.isEmpty then
    throw <| IO.userError s!"Could not find a mathlib dependency in {path}"
  if mathlib.size > 1 then
    throw <| IO.userError s!"Found multiple mathlib dependencies in {path}"
  let entry := mathlib[0]!
  let git ← match entry.git with
    | some g =>
        let g := g.trim
        if g.isEmpty then
          throw <| IO.userError s!"mathlib dependency in {path} is missing a non-empty 'git' field"
        else pure g
    | none =>
        throw <| IO.userError s!"mathlib dependency in {path} is missing a non-empty 'git' field"
  let rev ← match entry.rev with
    | some r =>
        let r := r.trim
        if r.isEmpty then
          throw <| IO.userError s!"mathlib dependency in {path} is missing a non-empty 'rev' field"
        else pure r
    | none =>
        throw <| IO.userError s!"mathlib dependency in {path} is missing a non-empty 'rev' field"
  return { name := "mathlib", git := git, rev := rev }

/-! ## ExtractedTheorem (subprocess result) -/

structure ExtractedTheorem where
  declarationName : String
  module : String
  startLine : Nat
  startColumn : Nat
  endLine : Nat
  endColumn : Nat
  explicitParameters : Option (Array String) := none
  sameModuleDependencies : Array String
  kind : String
  deriving Inhabited

private def parseExtractedTheorem (payload : String) : Except String ExtractedTheorem := do
  let json ← Json.parse payload
  let declarationName ← json.getObjValAs? String "declarationName"
  let module ← json.getObjValAs? String "module"
  let kind ← json.getObjValAs? String "kind"
  let range ← json.getObjVal? "sourceRange"
  let startLine ← range.getObjValAs? Nat "startLine"
  let startColumn ← range.getObjValAs? Nat "startColumn"
  let endLine ← range.getObjValAs? Nat "endLine"
  let endColumn ← range.getObjValAs? Nat "endColumn"
  let explicitParameters ← match json.getObjVal? "explicitParameters" with
    | .error _ => pure none
    -- `null` for a declaration whose signature the extractor could not read.
    | .ok paramsJson =>
        match paramsJson.getArr? with
        | .error _ => pure none
        | .ok paramsJson => do
            let mut params : Array String := #[]
            for paramJson in paramsJson do
              params := params.push (← paramJson.getStr?)
            pure (some params)
  let depNames : Array String ←
    match json.getObjVal? "sameModuleDependencies" with
    | .error _ => pure #[]
    | .ok arrJ => do
        let arr ← arrJ.getArr?
        let mut acc : Array String := #[]
        for d in arr do
          let s ← d.getStr?
          acc := acc.push s
        pure acc
  return {
    declarationName, module, startLine, startColumn, endLine, endColumn, explicitParameters
    sameModuleDependencies := depNames
    kind
  }

def buildExtractor (root : System.FilePath) (entries : Array EvalProblemMetadata) :
    IO Unit := do
  let modules := uniqueModules entries
  let _ ← runCmdCheckedCaptured "lake"
    (#["build"] ++ modules ++ #["extract_theorem"]) root
    "Failed to build Lean theorem extractor"
  pure ()

def extractOne (root : System.FilePath) (entry : EvalProblemMetadata) (hole : String) :
    IO ExtractedTheorem := do
  let binPath := root / ".lake" / "build" / "bin" / "extract_theorem"
  let out ← runCmdCheckedCaptured "lake"
    #["env", binPath.toString, entry.moduleName, hole] root
    s!"Lean extraction failed for '{entry.id}' hole '{hole}'"
  match parseExtractedTheorem out.stdout with
  | .ok e => pure e
  | .error err =>
      throw <| IO.userError
        s!"Lean extractor returned invalid JSON for '{entry.id}' hole '{hole}': {err}"

/-! ## Source paths -/

def moduleSourcePath (root : System.FilePath) (moduleName : String) : System.FilePath := Id.run do
  let parts := moduleName.splitOn "."
  let mut path := root
  for p in parts do
    path := path / p
  return path.addExtension "lean"

def ileanPath (root : System.FilePath) (moduleName : String) : System.FilePath := Id.run do
  let parts := moduleName.splitOn "."
  let mut path := root / ".lake" / "build" / "lib" / "lean"
  for p in parts do
    path := path / p
  return path.addExtension "ilean"

/-! ## Source-as-Array-Char utilities

Source-text manipulation works on `Array Char` so we can use `Nat` indices
directly. This matches Python's codepoint-indexed string semantics, which the
upstream `scripts/generate_projects.py` relies on (e.g. when applying offsets
from `.ilean`, which records codepoint columns). -/

abbrev Source := Array Char

def Source.ofString (s : String) : Source := s.toList.toArray

def Source.toString (s : Source) : String := String.mk s.toList

def Source.size (s : Source) : Nat := Array.size s

/-- Slice `s[start:end]` as a String. -/
def Source.slice (s : Source) (start endIdx : Nat) : String :=
  let endIdx := min endIdx s.size
  let start := min start endIdx
  String.mk (s.toList.drop start |>.take (endIdx - start))

/-- Convert (1-indexed line, 0-indexed codepoint column) into a codepoint
index in `s`. Mirrors `offset_for_line_column` in
`scripts/generate_projects.py`. -/
def Source.offsetForLineColumn (s : Source) (line col : Nat) : IO Nat := do
  if line < 1 then
    throw <| IO.userError s!"Invalid source line {line}"
  let mut currentLine : Nat := 1
  let mut idx : Nat := 0
  let n := s.size
  while currentLine < line do
    -- find next '\n'
    let mut found := false
    while idx < n do
      if s[idx]! == '\n' then
        idx := idx + 1
        found := true
        break
      idx := idx + 1
    if !found then
      throw <| IO.userError s!"Source ended before line {line}"
    currentLine := currentLine + 1
  return idx + col

/-- Find the first occurrence of `needle` (a `List Char`) in `s` starting at
`start`, returning the codepoint index where the match starts. -/
def Source.find (s : Source) (start : Nat) (needle : List Char) : Option Nat := Id.run do
  let n := s.size
  let m := needle.length
  if m == 0 then return some start
  let mut i := start
  while i + m ≤ n do
    let mut j := 0
    let mut matched := true
    for c in needle do
      if s[i + j]! != c then
        matched := false
        break
      j := j + 1
    if matched then return some i
    i := i + 1
  return none

/-- Find the LAST occurrence of `needle` in `s` strictly before `endIdx`. -/
def Source.rfind (s : Source) (endIdx : Nat) (needle : List Char) : Option Nat := Id.run do
  let n := min endIdx s.size
  let m := needle.length
  if m == 0 then return some n
  if m > n then return none
  let mut i : Nat := n - m + 1
  while i > 0 do
    let pos := i - 1
    let mut j := 0
    let mut matched := true
    for c in needle do
      if s[pos + j]! != c then
        matched := false
        break
      j := j + 1
    if matched then return some pos
    i := i - 1
  return none

/-- True if `s[i:]` starts with `needle`. -/
def Source.startsWithAt (s : Source) (i : Nat) (needle : List Char) : Bool := Id.run do
  let n := s.size
  let m := needle.length
  if i + m > n then return false
  let mut j := 0
  for c in needle do
    if s[i + j]! != c then return false
    j := j + 1
  return true

/-! ## Text utilities (line-based) -/

/-- Index just past the closing delimiter of the block comment beginning at
`start` (which must point at a block-comment opener), accounting for nested
block comments. Returns `source.size` if the comment is unterminated. -/
def blockCommentEnd (source : Source) (start : Nat) : Nat := Id.run do
  let n := source.size
  let openCh := "/-".toList
  let closeCh := "-/".toList
  let mut i := start
  let mut depth : Nat := 0
  while i < n do
    if Source.startsWithAt source i openCh then
      depth := depth + 1
      i := i + 2
    else if Source.startsWithAt source i closeCh then
      depth := depth - 1
      i := i + 2
      if depth == 0 then
        return i
    else
      i := i + 1
  return n

/-- Return `(endOfLastImport, bodyStart)` as codepoint indices in `source`.
Comments and whitespace are treated as header trivia, including nested block
comments. Thus comments before or between imports are included in
`endOfLastImport`, while a module doc comment after the last import remains
available to callers slicing from that offset. -/
def scanHeader (source : Source) : Nat × Nat := Id.run do
  let n := source.size
  let mut i : Nat := 0
  let mut endOfLastImport : Nat := 0
  while i < n do
    while i < n && source[i]!.isWhitespace do
      i := i + 1
    if i == n then return (endOfLastImport, n)
    if Source.startsWithAt source i "--".toList then
      while i < n && source[i]! != '\n' do
        i := i + 1
      continue
    if Source.startsWithAt source i "/-".toList then
      i := blockCommentEnd source i
      continue
    let importEnd := i + "import".length
    if Source.startsWithAt source i "import".toList
        && importEnd < n && source[importEnd]!.isWhitespace then
      while i < n && source[i]! != '\n' do
        i := i + 1
      if i < n then i := i + 1
      endOfLastImport := i
      continue
    return (endOfLastImport, i)
  return (endOfLastImport, n)

/-- Codepoint index just after the last import in the source header. -/
def importPreludeLength (source : Source) : Nat :=
  (scanHeader source).1

/-- True if the line's trimmed content is `import EvalTools.Markers`, allowing
arbitrary intra-line whitespace between `import` and the module name (the
Python regex was `\s+`, not a single space). -/
private def isEvalToolsMarkersImport (stripped : String) : Bool := Id.run do
  if !(stripped.startsWith "import") then return false
  let after := (stripped.drop "import".length).toString
  if after.isEmpty then return false
  if !after.toList.head!.isWhitespace then return false
  return after.trimAscii.toString == "EvalTools.Markers"

/-- True if the line is `import <m>` for some module `m` in `locals`, allowing
arbitrary intra-line whitespace between `import` and the module name. Used to
drop imports of repo-local modules whose declarations are inlined into
`ChallengeDeps`, so the generated workspace files don't import the (absent)
`LeanEval` library. -/
private def isLocalImport (stripped : String) (locals : Array String) : Bool := Id.run do
  if !(stripped.startsWith "import") then return false
  let after := (stripped.drop "import".length).toString
  if after.isEmpty then return false
  if !after.toList.head!.isWhitespace then return false
  let modName := ((after.trimAscii.toString.splitOn " ").head!).trimAscii.toString
  return locals.contains modName

/-- Strip `@[eval_problem]` attribute lines, `import EvalTools.Markers` lines,
and `import <m>` lines for each repo-local module `m` in `localImports` from
`source`. Blank lines immediately before and after a stripped line are also
dropped — mirroring the greedy `\s*` runs that bracket the attribute in
Python's `_strip_problem_markers` regex. -/
def stripProblemMarkers (source : String) (localImports : Array String := #[]) : String := Id.run do
  let lines := source.splitOn "\n"
  let mut out : Array String := #[]
  let mut eatBlanks := false
  for line in lines do
    let stripped := line.trimAscii.toString
    if stripped == "@[eval_problem]" || isEvalToolsMarkersImport stripped
        || isLocalImport stripped localImports then
      -- Drop blank lines we already pushed that immediately precede this
      -- marker line; the Python regex's leading `^\s*` consumes them too.
      while out.size > 0 && out[out.size - 1]!.trimAscii.toString.isEmpty do
        out := out.pop
      eatBlanks := true
      continue
    if eatBlanks && stripped.isEmpty then continue
    eatBlanks := false
    out := out.push line
  return "\n".intercalate out.toList

/-- Find the offset (codepoint index) of the first top-level `end ...` line at
or after `start`. Returns `source.size` if none found. Mirrors
`find_top_level_end_offset`. -/
def findTopLevelEndOffset (source : Source) (start : Nat) : Nat := Id.run do
  let n := source.size
  let mut i := start
  while i < n do
    -- start of a line. Check if line (verbatim, no leading whitespace) matches
    -- `end` optionally followed by `\s+<token>` and then end-of-line.
    let lineStart := i
    -- find end of line
    let mut j := i
    while j < n && source[j]! != '\n' do
      j := j + 1
    let lineEnd := j
    -- right-trim
    let mut k := lineEnd
    while k > lineStart && source[k - 1]!.isWhitespace do
      k := k - 1
    -- match `end` exactly or `end <something>`
    let endChars := "end".toList
    let isEnd : Bool := Id.run do
      if !(Source.startsWithAt source lineStart endChars) then return false
      let afterEnd := lineStart + 3
      if afterEnd == k then return true
      if afterEnd < k && (source[afterEnd]! == ' ' || source[afterEnd]! == '\t') then
        -- there must be some non-whitespace token before k
        let mut p := afterEnd
        while p < k && source[p]!.isWhitespace do
          p := p + 1
        return p < k
      return false
    if isEnd then return lineStart
    -- next line
    if j < n then i := j + 1 else i := j
  return n

/-! ## Source imports -/

def sourceImports (source : String) : Array String := Id.run do
  let mut out : Array String := #[]
  for line in source.splitOn "\n" do
    let stripped := line.trimAscii.toString
    if stripped.startsWith "import " then
      let rest := (stripped.drop "import ".length).trimAscii.toString
      let modName := ((rest.splitOn " ").head!).trimAscii.toString
      if !modName.isEmpty then
        out := out.push modName
  return out

partial def repoLocalImportModulesAux (root : System.FilePath) (moduleName : String)
    (seen : IO.Ref (Std.HashSet String)) : IO (Array String) := do
  let path := moduleSourcePath root moduleName
  if !(← path.pathExists) then return #[]
  let source ← IO.FS.readFile path
  let mut out : Array String := #[]
  for imported in sourceImports source do
    if imported.startsWith "Mathlib." || imported == "Mathlib" then continue
    if imported.startsWith "EvalTools." then continue
    if imported == moduleName then continue
    if (← seen.get).contains imported then continue
    let importedPath := moduleSourcePath root imported
    if !(← importedPath.pathExists) then continue
    seen.modify (·.insert imported)
    let nested ← repoLocalImportModulesAux root imported seen
    out := out ++ nested
    out := out.push imported
  return out

def repoLocalImportModules (root : System.FilePath) (moduleName : String) :
    IO (Array String) := do
  let seen ← IO.mkRef ({} : Std.HashSet String)
  repoLocalImportModulesAux root moduleName seen

/-! ## ILean metadata -/

/-- A declaration's source range from the `.ilean`, as
`[startLine, startColumn, endLine, endColumn]` (`.ilean` records these
0-indexed; we convert lines to 1-indexed to match `offsetForLineColumn`).
The range spans the *whole* declaration, doc comment through the end of the
body, so `(endLine, endColumn)` is the precise end — no heuristic needed. -/
structure IleanDeclEntry where
  name : String
  startLine : Nat
  startColumn : Nat
  endLine : Nat
  endColumn : Nat
  deriving Inhabited

def loadIleanDeclRanges (root : System.FilePath) (moduleName : String) :
    IO (Array IleanDeclEntry) := do
  let path := ileanPath root moduleName
  if !(← path.pathExists) then
    throw <| IO.userError
      s!"Compiled metadata for module '{moduleName}' not found: {path}"
  let contents ← IO.FS.readFile path
  let json ← match Json.parse contents with
    | .ok j => pure j
    | .error err =>
        throw <| IO.userError
          s!"Invalid JSON in compiled metadata for module '{moduleName}': {err}"
  let decls ← match json.getObjVal? "decls" with
    | .ok d => pure d
    | .error _ => return #[]
  let obj ← match decls.getObj? with
    | .ok o => pure o
    | .error _ => return #[]
  let mut out : Array IleanDeclEntry := #[]
  for ⟨name, value⟩ in obj.toArray do
    match value.getArr? with
    | .error _ => continue
    | .ok arr =>
        if arr.size < 4 then continue
        match arr[0]!.getNat?, arr[1]!.getNat?, arr[2]!.getNat?, arr[3]!.getNat? with
        | .ok line, .ok col, .ok endLine, .ok endCol =>
            out := out.push
              { name, startLine := line + 1, startColumn := col
                endLine := endLine + 1, endColumn := endCol }
        | _, _, _, _ => continue
  return out

/-! ## Header scanning, namespace ops -/

/-- Insert `line` (must end in `\n`) just after the last import line at the
top of `source`. Mirrors `_inject_after_imports`. -/
def injectAfterImports (source line : String) : String := Id.run do
  let src := Source.ofString source
  let (insertAt, _) := scanHeader src
  if insertAt == 0 then
    return "import Mathlib\n" ++ line ++ source
  let before := Source.slice src 0 insertAt
  let after := Source.slice src insertAt src.size
  return before ++ line ++ after

/-- Top-level namespace names declared in `body`, in source order. Mirrors
`_top_level_namespaces`. -/
def topLevelNamespaces (body userNamespace : String) : Array String := Id.run do
  let mut byOrder : Array String := #[]
  let mut seen : Std.HashSet String := {}
  let mut depth : Int := 0
  for raw in body.splitOn "\n" do
    let lstripped := raw.trimAsciiStart.toString
    if lstripped.startsWith "--" then continue
    if lstripped.startsWith "namespace " then
      let rest := (lstripped.drop "namespace ".length).trimAscii.toString
      let name := ((rest.splitOn " ").head!).trimAscii.toString
      if depth == 0 && name != userNamespace && !seen.contains name then
        byOrder := byOrder.push name
        seen := seen.insert name
      depth := depth + 1
      continue
    -- `end` followed by space (or just `end`); Python uses `^end\b`
    if lstripped.startsWith "end " || lstripped == "end" then
      depth := depth - 1
      continue
  return byOrder

/-- Wrap `source`'s body in `namespace Submission ... end Submission`.
Mirrors `_wrap_body_in_submission_namespace`. -/
def wrapBodyInSubmissionNamespace (source userNamespace : String)
    (extraOpens : Array String := #[]) : String := Id.run do
  let src := Source.ofString source
  let (_, bodyStart) := scanHeader src
  if bodyStart ≥ src.size then return source
  let head := Source.slice src 0 bodyStart
  let mut body := Source.slice src bodyStart src.size
  if !body.endsWith "\n" then body := body ++ "\n"
  -- Open `extraOpens` (the `_root_`-qualified enclosing namespaces of trusted
  -- helpers now living in `ChallengeDeps`) together with the source's own
  -- top-level namespaces (so cross-namespace references in the wrapped body
  -- still resolve). `extraOpens` come first and are authoritative: a bare
  -- auto-open of the same base name is redundant (it would resolve to the
  -- wrapped `Submission.X`, not the helper's `_root_.X`) and is dropped.
  let normalize := fun (s : String) =>
    if s.startsWith "_root_." then (s.drop 7).toString else s
  let mut openNamespaces : Array String := #[]
  let mut seenBase : Std.HashSet String := {}
  for ns in extraOpens ++ topLevelNamespaces body userNamespace do
    let base := normalize ns
    if seenBase.contains base then continue
    openNamespaces := openNamespaces.push ns
    seenBase := seenBase.insert base
  let opens := openNamespaces.foldl (fun acc ns => acc ++ s!"open {ns}\n") ""
  return head ++ "\nnamespace Submission\n\n" ++ opens ++ body ++ "\nend Submission\n"

/-! ## Theorem statement / binder parsing -/

def lastComponentStr (name : String) : String :=
  match (name.splitOn ".").getLast? with
  | some s => s
  | none => name

/-- Word boundary at codepoint index `i`: index is past-the-end, at position
0, or preceded by a non-word char. -/
def Source.atWordStart (s : Source) (i : Nat) : Bool :=
  i == 0 || (
    let c := s[i - 1]!
    !(c.isAlphanum || c == '_' || c == '\''))

def Source.atWordEnd (s : Source) (i : Nat) : Bool :=
  i ≥ s.size || (
    let c := s[i]!
    !(c.isAlphanum || c == '_' || c == '\''))

/-- Find the first occurrence of `theorem <name>` (with word boundaries) at or
after `start`, returning the codepoint index just past the name. Mirrors the
header regex in `extract_statement_text`. -/
def Source.findTheoremHeader (s : Source) (start : Nat) (name : String) : Option Nat := Id.run do
  let needle := s!"theorem {name}".toList
  let nameSize := name.length
  let needleLen := needle.length
  let mut i := start
  let n := s.size
  while i + needleLen ≤ n do
    if Source.startsWithAt s i needle then
      let prevOk := i == 0 || s[i - 1]!.isWhitespace
      let endPos := i + needleLen
      let afterOk := Source.atWordEnd s endPos
      let _ := nameSize  -- silence unused warning
      if prevOk && afterOk then
        return some endPos
    i := i + 1
  return none

/-- Skip whitespace and Lean comments from `start`. Block comments are nested. -/
def Source.skipTrivia (s : Source) (start : Nat) : Nat := Id.run do
  let mut i := start
  while i < s.size do
    if s[i]!.isWhitespace then
      i := i + 1
    else if Source.startsWithAt s i "--".toList then
      while i < s.size && s[i]! != '\n' do
        i := i + 1
    else if Source.startsWithAt s i "/-".toList then
      i := blockCommentEnd s i
    else
      break
  return i

/-- Skip a double-quoted string, including escaped characters. `start` must
point at the opening quote. -/
private def Source.stringLiteralEnd (s : Source) (start : Nat) : Nat := Id.run do
  let mut i := start + 1
  while i < s.size do
    if s[i]! == '\\' then
      i := min (i + 2) s.size
    else if s[i]! == '"' then
      return i + 1
    else
      i := i + 1
  return s.size

/-- If `start` begins a character literal, return its end. Apostrophes used in
identifiers are rejected by requiring a closing quote in the literal shape. -/
private def Source.charLiteralEnd? (s : Source) (start : Nat) : Option Nat :=
  if start + 2 < s.size && s[start + 2]! == '\'' then some (start + 3)
  else if start + 3 < s.size && s[start + 1]! == '\\' && s[start + 3]! == '\'' then
    some (start + 4)
  else none

/-- Skip a French-quoted identifier such as `«a := by»`. -/
private def Source.quotedIdentifierEnd (s : Source) (start : Nat) : Nat := Id.run do
  let mut i := start + 1
  while i < s.size do
    if s[i]! == '»' then return i + 1
    i := i + 1
  return s.size

/-- Locate the body marker of an eval-problem theorem without assuming the
literal spelling `:= by`. Candidates inside comments, strings, and brackets are
ignored, so a default binder value such as `(h : P := by tac)` cannot be
mistaken for the declaration body; arbitrary trivia may follow `:=`; and both
the usual `by sorry` body and a direct `sorry` body are accepted.

An eval-problem hole's body is a `sorry`, so a candidate whose body is exactly
`sorry` (behind `by` or not) and runs to the end of the declaration wins over
every other candidate: a *statement* may itself contain a top-level
`haveI … := by …`, and that tactic block is not the body.

Failing that — the `ci_regenerate_main_check` canary really is proved by
`trivial` — a candidate opening a tactic block is used, but only if it is the
only one. With a body that is not a `sorry` there is nothing left to tell an
assignment in the statement apart from an assignment in the proof, so `none` is
returned and the caller reports that it could not recover the statement. -/
structure TheoremBody where
  /-- Codepoint index of the `:=` that introduces the declaration's body. -/
  marker : Nat
  /-- Whether that body is a bare `sorry`, possibly behind `by`. -/
  isBareSorry : Bool
  deriving Inhabited

def Source.findTheoremBodyMarker (s : Source) (start : Nat) : Option TheoremBody := Id.run do
  let mut i := start
  let mut roundDepth := 0
  let mut squareDepth := 0
  let mut braceDepth := 0
  let mut angleDepth := 0
  let mut sorryMarker : Option Nat := none
  let mut tacticMarker : Option Nat := none
  let mut tacticMarkers := 0
  while i < s.size do
    if Source.startsWithAt s i "--".toList then
      while i < s.size && s[i]! != '\n' do
        i := i + 1
    else if Source.startsWithAt s i "/-".toList then
      i := blockCommentEnd s i
    else if s[i]! == '"' then
      i := Source.stringLiteralEnd s i
    else if s[i]! == '\'' then
      match Source.charLiteralEnd? s i with
      | some literalEnd => i := literalEnd
      | none => i := i + 1
    else if s[i]! == '«' then
      i := Source.quotedIdentifierEnd s i
    else if s[i]! == '(' then roundDepth := roundDepth + 1; i := i + 1
    else if s[i]! == ')' then roundDepth := roundDepth - 1; i := i + 1
    else if s[i]! == '[' then squareDepth := squareDepth + 1; i := i + 1
    else if s[i]! == ']' then squareDepth := squareDepth - 1; i := i + 1
    else if s[i]! == '{' then braceDepth := braceDepth + 1; i := i + 1
    else if s[i]! == '}' then braceDepth := braceDepth - 1; i := i + 1
    else if s[i]! == '⟨' then angleDepth := angleDepth + 1; i := i + 1
    else if s[i]! == '⟩' then angleDepth := angleDepth - 1; i := i + 1
    else if roundDepth == 0 && squareDepth == 0 && braceDepth == 0 && angleDepth == 0
        && Source.startsWithAt s i ":=".toList then
      let bodyStart := Source.skipTrivia s (i + 2)
      let tacticBody := Source.startsWithAt s bodyStart "by".toList
        && Source.atWordEnd s (bodyStart + "by".length)
      let termStart :=
        if tacticBody then Source.skipTrivia s (bodyStart + "by".length) else bodyStart
      if Source.startsWithAt s termStart "sorry".toList
          && Source.atWordEnd s (termStart + "sorry".length)
          && Source.skipTrivia s (termStart + "sorry".length) == s.size then
        sorryMarker := some i
      else if tacticBody then
        tacticMarker := some i
        tacticMarkers := tacticMarkers + 1
      i := i + 2
    else
      i := i + 1
  return match sorryMarker with
    | some marker => some { marker, isBareSorry := true }
    | none =>
        if tacticMarkers == 1 then tacticMarker.map ({ marker := ·, isBareSorry := false })
        else none

/-- Extract the theorem statement text from a sliced declaration body.
The body marker is found lexically so direct `:= sorry` holes and flexible
whitespace/comment formatting are supported. -/
def extractStatementText (problemId : String) (sourcePath : System.FilePath)
    (declarationText theoremName : String) : IO String := do
  let src := Source.ofString declarationText
  let some headerEnd := Source.findTheoremHeader src 0 theoremName
    | throw <| IO.userError
        s!"Could not recover theorem statement text for '{problemId}' from {sourcePath}"
  let some body := Source.findTheoremBodyMarker src headerEnd
    | throw <| IO.userError
        s!"Could not recover theorem statement text for '{problemId}' from {sourcePath}"
  if body.marker < headerEnd then
    throw <| IO.userError
      s!"Could not recover theorem statement text for '{problemId}' from {sourcePath}"
  return (Source.slice src headerEnd body.marker).trimAscii.toString

/-- True when the sliced declaration's body is a bare `sorry`, possibly behind
`by`. Only then does the elaborated value carry one lambda per signature
binder, so only then is the extractor's parameter list meaningful: `by intro x;
sorry` elaborates to a lambda over `sorryAx` as well, but its lambda belongs to
the statement. -/
def hasBareSorryBody (declarationText : String) : Bool :=
  match Source.findTheoremBodyMarker (Source.ofString declarationText) 0 with
  | some body => body.isBareSorry
  | none => false

/-- Parse leading binders off a theorem-statement string. Returns pairs of
`(opener, body)` for each leading `(...)`, `{...}`, or `[...]` group. -/
def leadingBinders (statement : String) : Array (Char × String) := Id.run do
  let s := Source.ofString statement
  let n := s.size
  let mut binders : Array (Char × String) := #[]
  let mut i : Nat := 0
  let mut done := false
  while i < n && !done do
    while i < n && s[i]!.isWhitespace do
      i := i + 1
    if i ≥ n then break
    let opener := s[i]!
    let closer? : Option Char :=
      match opener with
      | '(' => some ')'
      | '{' => some '}'
      | '[' => some ']'
      | _ => none
    match closer? with
    | none => done := true
    | some closer =>
        let start := i
        let mut depth : Nat := 0
        let mut closed := false
        let mut j := i
        while j < n do
          let ch := s[j]!
          if ch == opener then
            depth := depth + 1
          else if ch == closer then
            depth := depth - 1
            if depth == 0 then
              let body := (Source.slice s (start + 1) j).trimAscii.toString
              binders := binders.push (opener, body)
              j := j + 1
              closed := true
              break
          j := j + 1
        i := j
        if !closed then done := true
  return binders

/-- Split `s` into whitespace-delimited tokens (empty tokens dropped). -/
private def splitWhitespace (s : String) : Array String := Id.run do
  let mut out : Array String := #[]
  let mut current : String := ""
  for c in s.toList do
    if c.isWhitespace then
      if !current.isEmpty then
        out := out.push current
        current := ""
    else
      current := current.push c
  if !current.isEmpty then
    out := out.push current
  return out

def explicitBinderApplicationArgs (statement : String) : Array String := Id.run do
  let mut args : Array String := #[]
  for (opener, body) in leadingBinders statement do
    if opener != '(' then continue
    let parts := body.splitOn ":"
    if parts.length < 2 then continue
    for name in splitWhitespace parts[0]! do
      args := args.push name
  return args

/-- Strip the `:= <body>` off the end of a sliced declaration. Mirrors
`_hole_decl_signature`. -/
def holeDeclSignature (declText basename : String) : IO String := do
  let stripped := (stripProblemMarkers declText).trimAscii.toString
  let src := Source.ofString stripped
  let some idx := Source.rfind src src.size ":=".toList
    | throw <| IO.userError
        s!"Hole '{basename}' declaration has no `:=` to split: {stripped.quote}"
  let prefix' := (Source.slice src 0 idx).trimAsciiEnd.toString
  return prefix' ++ " := "

/-- Find `<keyword> <basename>` for any keyword in `keywords`, with word
boundaries. Returns the codepoint position of the start of the keyword and
the position just past the basename. -/
def Source.findKeywordBasename (s : Source) (keywords : Array String) (basename : String) :
    Option (Nat × Nat) := Id.run do
  let n := s.size
  let basenameLen := basename.length
  let basenameChars := basename.toList
  let mut i : Nat := 0
  while i < n do
    if Source.atWordStart s i then
      for kw in keywords do
        let kwChars := kw.toList
        let kwLen := kw.length
        if Source.startsWithAt s i kwChars then
          let afterKw := i + kwLen
          if afterKw < n && s[afterKw]!.isWhitespace then
            -- consume whitespace
            let mut j := afterKw
            while j < n && s[j]!.isWhitespace do
              j := j + 1
            if Source.startsWithAt s j basenameChars then
              let endBase := j + basenameLen
              if Source.atWordEnd s endBase then
                return some (i, endBase)
    i := i + 1
  return none

/-- Rewrite a non-theorem hole signature for the `Solution.lean` delegation:
inject `@[reducible] noncomputable` immediately before the declaration
keyword. The delegation must be `noncomputable` because honest solutions to
data holes are frequently noncomputable (e.g. `genus` in the Jacobian
challenge), and a computable `def` whose body references a noncomputable
`Submission.<name>` fails to compile; comparator never sees computability,
so the marker is invisible to scoring. An existing `noncomputable` modifier
in the source signature is folded into the rewrite — Lean's grammar puts
attributes before `noncomputable`, so leaving it in place would produce the
invalid `noncomputable @[reducible] def`. Returns `none` when no
`def`/`instance`/`abbrev` keyword anchors the basename. -/
def injectSolutionHoleModifiers (signature basename : String) : Option String := do
  let sigSrc := Source.ofString signature
  let (kwStart, _) ← Source.findKeywordBasename sigSrc #["def", "instance", "abbrev"] basename
  let prefixText := Source.slice sigSrc 0 kwStart
  let trimmed := prefixText.trimAsciiEnd.toString
  let noncomputableKw := "noncomputable"
  let prefixText :=
    if trimmed == noncomputableKw then
      ""
    else if trimmed.endsWith noncomputableKw &&
        (trimmed.dropRight noncomputableKw.length).back.isWhitespace then
      trimmed.dropRight noncomputableKw.length
    else
      prefixText
  return prefixText ++ "@[reducible] noncomputable " ++ Source.slice sigSrc kwStart sigSrc.size

/-! ## Context opens -/

/-- Drop block comments `/- … -/` (nested-aware) that open and close on the
same line. Multi-line block comments are left alone — they're handled by
peeking through whole comment-only lines in the line scanner. -/
private def stripSingleLineBlockComments (s : String) : String := Id.run do
  let chars := s.toList.toArray
  let n := chars.size
  let mut out : String := ""
  let mut i : Nat := 0
  let mut depth : Nat := 0
  while i < n do
    if i + 1 < n && chars[i]! == '/' && chars[i + 1]! == '-' then
      depth := depth + 1
      i := i + 2
    else if depth > 0 && i + 1 < n && chars[i]! == '-' && chars[i + 1]! == '/' then
      depth := depth - 1
      i := i + 2
    else
      if depth == 0 then out := out.push chars[i]!
      i := i + 1
  return out

/-- Drop a trailing `--` line comment from `s`. Used together with
`stripSingleLineBlockComments` to keep `in` tokens that appear in comments
from being mistaken for the `open … in` scoping keyword. -/
private def stripLineComment (s : String) : String :=
  match s.splitOn "--" with
  | x :: _ => x
  | [] => s

/-- True if `stripped` is a scoped `open … in …` line — the single-command
form that binds an open to one following expression. Detected by an `in`
token appearing somewhere after the leading `open` keyword. Top-level opens
like `open Foo` or `open scoped Classical` return false. -/
def isScopedOpenLine (stripped : String) : Bool := Id.run do
  if !(stripped.startsWith "open ") then return false
  let toks := splitWhitespace (stripLineComment (stripSingleLineBlockComments stripped))
  for i in [1:toks.size] do
    if toks[i]! == "in" then return true
  return false

/-- True if the upcoming lines starting at `peekIdx` (0-indexed) form the
continuation of a scoped `open … in` — that is, after any blank or
comment-only lines, the next syntactic line is `in` or begins with `in `.
Used to catch the multi-line variant where `in` is on its own line. -/
private def followingLineIsScopingIn (lines : Array String) (peekIdx : Nat) : Bool := Id.run do
  let mut i := peekIdx
  while i < lines.size do
    let s := (lines[i]!).trimAscii.toString
    if s.isEmpty || s.startsWith "--" then
      i := i + 1
    else
      return s == "in" || s.startsWith "in "
  return false

def extractContextOpens (problemId : String) (sourcePath : System.FilePath)
    (source : String) (extracted? : Option ExtractedTheorem)
    (includeNamespaces : Bool) : IO String := do
  let _ := problemId
  let _ := sourcePath
  let lines := (source.splitOn "\n").toArray
  let targetLine? : Option Nat := extracted?.map fun e => e.startLine
  let mut namespaceStack : Array String := #[]
  let mut openLayers : Array (Array String) := #[#[]]
  let mut inBody := false
  let mut done := false
  for idx in [1:lines.size + 1] do
    if done then break
    if let some t := targetLine? then
      if idx ≥ t then break
    let line := lines[idx - 1]!
    let stripped := line.trimAscii.toString
    if !inBody then
      if stripped.startsWith "import " || stripped.isEmpty then continue
      inBody := true
    if targetLine?.isNone then
      let declKeywords := #["theorem", "lemma", "def", "abbrev", "opaque",
        "axiom", "instance", "class", "structure"]
      let isDecl := Id.run do
        if stripped.startsWith "@[" then return true
        for kw in declKeywords do
          if stripped.startsWith kw then
            let after := (stripped.drop kw.length).toString
            if after.isEmpty then return true
            -- check next char is non-word
            let c := after.toList.head!
            if !(c.isAlphanum || c == '_' || c == '\'') then return true
        return false
      if isDecl then
        done := true
        continue
    if stripped.startsWith "namespace " then
      let rest := (stripped.drop "namespace ".length).trimAscii.toString
      let name := ((rest.splitOn " ").head!).trimAscii.toString
      namespaceStack := namespaceStack.push name
      openLayers := openLayers.push #[]
    else if stripped.startsWith "end " || stripped == "end" then
      if namespaceStack.size > 0 then
        namespaceStack := namespaceStack.pop
        openLayers := openLayers.pop
    else if stripped.startsWith "open " then
      if isScopedOpenLine stripped then continue
      -- Multi-line scoped form: `open Foo` on one line, `in <body>` on a
      -- following (possibly blank/comment-padded) line. Skip the whole
      -- thing rather than emitting a dangling `open Foo` as top-level.
      if followingLineIsScopingIn lines idx then continue
      let layerIdx := openLayers.size - 1
      let layer := openLayers[layerIdx]!.push line
      openLayers := openLayers.set! layerIdx layer
  let mut contextLines : Array String := #[]
  for layer in openLayers do
    for ln in layer do
      contextLines := contextLines.push ln
  if includeNamespaces && namespaceStack.size > 0 then
    let nsLine := "open " ++ ".".intercalate namespaceStack.toList
    contextLines := #[nsLine] ++ contextLines
  if contextLines.isEmpty then return ""
  return "\n".intercalate contextLines.toList ++ "\n\n"

/-! ## Context variables

Walk the source up to the theorem and collect every `variable` declaration
that is still in scope at that point. The lidskii regression (issue #276) is
the canonical example: a theorem can refer to identifiers like `n` that are
introduced by a preceding `variable {n : Type*} ...` declaration, and the
elaborated theorem inherits those binders even though they do not appear in
the source slice between `theorem <name>` and `:= by`. Re-emitting the
`variable` lines in the generated workspace restores the elaboration context
needed to type-check the extracted statement.

Multi-line `variable` declarations are kept verbatim: after a `variable`
header line we keep absorbing lines that begin with whitespace, which matches
how Lean's parser treats indented continuations of a binder list. -/

private def isLineStartingWithWhitespace (line : String) : Bool :=
  match line.toList with
  | [] => false
  | c :: _ => c.isWhitespace

/-- True iff `s` starts with `kw` and the next character (if any) is not part of
an identifier — i.e. `kw` is followed by whitespace or end-of-line, not by more
letters/underscores. Avoids matching `variableFoo` as `variable`. -/
private def startsWithKeyword (s kw : String) : Bool :=
  if !(s.startsWith kw) then false
  else
    let chars := s.toList.drop kw.length
    match chars with
    | [] => true
    | c :: _ => !(c.isAlphanum || c == '_' || c == '\'')

-- Drop the prefix of length `n` from `s` as a `String`.
private def stringDrop (s : String) (n : Nat) : String :=
  String.mk (s.toList.drop n)

-- Find the contents of `s` after the first occurrence of `"-/"`. If the
-- closer appears, returns `(afterMarker, false)`; otherwise returns
-- `("", true)` to signal the block comment is still open at end-of-line.
private def skipToBlockCommentClose (s : String) : String × Bool :=
  let parts := s.splitOn "-/"
  match parts with
  | [] => ("", true)
  | [_] => ("", true)
  | _ :: rest => ("-/".intercalate rest, false)

-- Strip a single block comment from the start of `lineRemainder`, returning
-- `(remainderAfterComment, stillOpen)`. Caller must ensure `lineRemainder`
-- starts with the block-comment opener `/-`.
private def consumeBlockCommentStart (lineRemainder : String) : String × Bool :=
  skipToBlockCommentClose (stringDrop lineRemainder 2)

-- Strip text up to and including the next block-comment closer, returning
-- what's left on this line and whether the block comment is still open.
private def consumeBlockCommentContinuation (lineRemainder : String) : String × Bool :=
  skipToBlockCommentClose lineRemainder

/-- Names introduced by the named (non-instance) leading binders of a
declaration-like text such as a theorem signature or the body of a
`variable` declaration. -/
def binderIntroducedNames (text : String) : Array String := Id.run do
  let mut names : Array String := #[]
  for (opener, body) in leadingBinders text do
    -- Instance-implicit binders are usually anonymous (`[Fintype n]`); skip
    -- them — the names they reference come from other binders.
    if opener == '[' then continue
    let parts := body.splitOn ":"
    if parts.length < 2 then continue
    for name in splitWhitespace parts[0]! do
      names := names.push name
  return names

/-- True iff every name introduced by `varText` (a `variable ...` line, with
the `variable` prefix still attached) is already bound by `theoremBinderNames`.
Such a `variable` is shadowed by the theorem's explicit binders and so
Lean would emit it as an "unused variable" if we re-emitted it. -/
private def variableShadowedByTheorem (varText : String)
    (theoremBinderNames : Array String) : Bool := Id.run do
  let trimmed := varText.trimAscii.toString
  if !(startsWithKeyword trimmed "variable") then return false
  let body := (trimmed.drop "variable".length).toString
  let varNames := binderIntroducedNames body
  if varNames.isEmpty then return false
  for name in varNames do
    if !theoremBinderNames.contains name then return false
  return true

/-- Syntax declarations are source context, not mathematical helpers, but
extracted statements and kept declarations may depend on their notation. -/
private def isSyntaxContextDeclaration (declarationText : String) : Bool := Id.run do
  let text := declarationText.trimAsciiStart.toString
  let prefixes := #[
    "notation", "local notation", "scoped notation",
    "infix", "infixl", "infixr", "prefix", "postfix",
    "local infix", "local infixl", "local infixr", "local prefix", "local postfix",
    "scoped infix", "scoped infixl", "scoped infixr", "scoped prefix", "scoped postfix",
    "syntax", "local syntax", "scoped syntax", "macro", "macro_rules"
  ]
  for kw in prefixes do
    if startsWithKeyword text kw then return true
  return false

private def isLocalSyntaxContextDeclaration (declarationText : String) : Bool := Id.run do
  let text := declarationText.trimAsciiStart.toString
  let prefixes := #[
    "local notation", "local infix", "local infixl", "local infixr",
    "local prefix", "local postfix", "local syntax"
  ]
  for kw in prefixes do
    if startsWithKeyword text kw then return true
  return false

/-- Top-level command keywords that begin a fresh declaration/command. A
whitespace-indented line opening with one of these is never a continuation of a
preceding `variable`/`universe` block (Lean permits indented top-level
commands), so the block scanner must stop before absorbing it. -/
private def startsWithCommandKeyword (stripped : String) : Bool := Id.run do
  if stripped.startsWith "@[" then return true
  if isSyntaxContextDeclaration stripped then return true
  let kws := #["def", "theorem", "lemma", "instance", "abbrev", "opaque",
    "axiom", "class", "structure", "inductive", "namespace", "section", "end",
    "variable", "universe", "open", "example", "noncomputable", "private",
    "protected", "scoped", "attribute", "macro", "notation", "syntax"]
  for kw in kws do
    if startsWithKeyword stripped kw then return true
  return false

/-- Walk `source` up to `extracted?`'s start line, collecting top-level command
blocks that begin with `keyword` (e.g. `variable` or `universe`), respecting
`section`/`namespace` scoping: a block declared inside a `section`/`namespace`
goes out of scope at the matching `end`. Multi-line blocks absorb following
whitespace-indented continuation lines. Each collected block is filtered through
`keep`; only blocks for which `keep` returns true are emitted. Returns the kept
blocks joined by newlines with a trailing blank line, or `""` if none. -/
private def extractScopedCommandBlocksWhere (source : String)
    (extracted? : Option ExtractedTheorem) (isMatch : String → Bool)
    (keep : String → Bool) : String := Id.run do
  let lines := source.splitOn "\n"
  let targetLine? : Option Nat := extracted?.map fun e => e.startLine
  let mut layers : Array (Array String) := #[#[]]
  let mut frameDepth : Nat := 0
  let mut inBlockComment := false
  let mut idx : Nat := 0
  while idx < lines.length do
    let lineNum := idx + 1
    if let some t := targetLine? then
      if lineNum ≥ t then break
    let line := lines[idx]!
    -- Walk the line tracking block-comment state. We only consider the
    -- non-comment remainder when classifying the line.
    let mut work := line
    if inBlockComment then
      let (rest, stillOpen) := consumeBlockCommentContinuation work
      if stillOpen then
        idx := idx + 1
        continue
      inBlockComment := false
      work := rest
    -- Strip any further `/- ... -/` segments that close on this line, and
    -- detect an opener that doesn't.
    let mut classified := work
    let mut bail := false
    while true do
      let trimmed := classified.trimAsciiStart.toString
      if trimmed.startsWith "/-" then
        let (rest', stillOpen) := consumeBlockCommentStart trimmed
        if stillOpen then
          inBlockComment := true
          bail := true
          break
        classified := rest'
      else
        break
    if bail then
      idx := idx + 1
      continue
    let stripped := classified.trimAscii.toString
    if stripped.isEmpty || stripped.startsWith "--" then
      idx := idx + 1
      continue
    if startsWithKeyword stripped "namespace" || startsWithKeyword stripped "section" then
      frameDepth := frameDepth + 1
      layers := layers.push #[]
      idx := idx + 1
    else if startsWithKeyword stripped "end" then
      if frameDepth > 0 then
        frameDepth := frameDepth - 1
        layers := layers.pop
      idx := idx + 1
    else if isMatch stripped then
      let mut block := line
      idx := idx + 1
      while idx < lines.length do
        let lineNum' := idx + 1
        if let some t := targetLine? then
          if lineNum' ≥ t then break
        let next := lines[idx]!
        if next.trimAscii.toString.isEmpty then break
        if !isLineStartingWithWhitespace next then break
        if startsWithCommandKeyword next.trimAsciiStart.toString then break
        block := block ++ "\n" ++ next
        idx := idx + 1
      if keep block then
        let layerIdx := layers.size - 1
        let layer := layers[layerIdx]!.push block
        layers := layers.set! layerIdx layer
    else
      idx := idx + 1
  let mut flat : Array String := #[]
  for layer in layers do
    for v in layer do
      flat := flat.push v
  if flat.isEmpty then return ""
  return "\n".intercalate flat.toList ++ "\n\n"

def extractScopedCommandBlocks (source : String) (extracted? : Option ExtractedTheorem)
    (keyword : String) (keep : String → Bool) : String :=
  extractScopedCommandBlocksWhere source extracted?
    (fun stripped => startsWithKeyword stripped keyword) keep

def extractContextVariables (source : String) (extracted? : Option ExtractedTheorem)
    (theoremBinderNames : Array String) : String :=
  -- One layer per `section`/`namespace` we are still inside, matching Lean's
  -- scoping for `variable`. Blocks shadowed by the theorem's own binders are
  -- dropped (they would otherwise be flagged as unused).
  extractScopedCommandBlocks source extracted? "variable"
    (fun block => !variableShadowedByTheorem block theoremBinderNames)

/-- Collect top-level `universe` commands in scope at the theorem. A source
module may declare `universe u v` and refer to `u`/`v` in a theorem whose
reconstructed `Challenge.lean` slice (`theorem … := by sorry`) would otherwise
have no binder for them, failing with `unknown universe level`. Re-emitting the
in-scope `universe` commands restores them. -/
def extractContextUniverses (source : String) (extracted? : Option ExtractedTheorem) : String :=
  extractScopedCommandBlocks source extracted? "universe" (fun _ => true)

/-- Collect the `include` and `omit` commands in scope at the theorem. These
decide which of the surrounding `variable` binders the declaration actually
takes, so re-emitting the `variable` commands without them would give the
generated declaration a different signature from the source one — and the
delegation arguments derived from the source declaration would not fit. -/
def extractContextIncludes (source : String) (extracted? : Option ExtractedTheorem) : String :=
  extractScopedCommandBlocksWhere source extracted?
    (fun stripped => startsWithKeyword stripped "include" || startsWithKeyword stripped "omit")
    (fun _ => true)

/-- Collect notation, syntax, and macro commands still in scope at the target
declaration. Generated statements retain their source notation, so these
commands must accompany them just like scoped variables and universes do. -/
def extractContextSyntaxDeclarations (source : String)
    (extracted? : Option ExtractedTheorem) : String :=
  extractScopedCommandBlocksWhere source extracted? isSyntaxContextDeclaration (fun _ => true)

def extractContextLocalSyntaxDeclarations (source : String)
    (extracted? : Option ExtractedTheorem) : String :=
  extractScopedCommandBlocksWhere source extracted? isLocalSyntaxContextDeclaration (fun _ => true)

/-! ## Delegation arguments -/

/-- Explicit (parenthesised) binder names introduced by the `variable` commands
in `block`, the text produced by `extractContextVariables`. These are the outer
parameters the generated files re-declare ahead of the restated signature, so
they are the only names a delegation may legitimately apply beyond the
declaration's own binders. -/
def variableBlockExplicitNames (block : String) : Array String := Id.run do
  let mut names : Array String := #[]
  let mut current : Option String := none
  for line in block.splitOn "\n" do
    let stripped := line.trimAsciiStart.toString
    if startsWithKeyword stripped "variable" then
      if let some command := current then
        names := names ++ explicitBinderApplicationArgs command
      current := some (stripped.drop "variable".length).toString
    else if let some command := current then
      current := some (command ++ "\n" ++ line)
  if let some command := current then
    names := names ++ explicitBinderApplicationArgs command
  return names

/-- The arguments the generated delegation must apply to `Submission.<name>`.

`sourceArgs` are the explicit binders parsed out of the declaration's own
source signature. A module may introduce further explicit parameters through
outer `variable` commands; Lean retains those in the elaborated declaration and
the generated files re-declare them, so they precede `sourceArgs` in
application order. `signatureParams?` is the extractor's report of the full
list.

The extractor's list is only trusted when it agrees with what the source
shows: it must end with `sourceArgs`, and every name ahead of them must be
introduced by one of the re-emitted `variable` commands.

When the two views disagree there is no safe answer, because the disagreement
is itself evidence that one of them is wrong: delegating on either would emit a
workspace that does not compile. `none` is returned so the caller can fail
instead.

`signatureParams?` is `none` for a declaration the extractor could not read.
The source binders are then all we have, and they are enough only when no outer
`variable` command could have contributed a parameter we cannot see. -/
def delegationArgs? (signatureParams? : Option (Array String))
    (variableNames sourceArgs : Array String) : Option (Array String) := Id.run do
  let some params := signatureParams?
    | return if variableNames.isEmpty then some sourceArgs else none
  if params.size < sourceArgs.size then return none
  let outerCount := params.size - sourceArgs.size
  if params.extract outerCount params.size != sourceArgs then return none
  if !(params.extract 0 outerCount).all (fun p => variableNames.contains p) then return none
  return some params

/-! ## Render ChallengeDeps.lean -/

/-- The byte range `[start, stop)` of a single source declaration in `sourceText`,
keyed by the declaration's full name. `stop` is either the next declaration's
`start` (taken from `.ilean`) or the matching top-level `end ...` line. -/
structure DeclSpan where
  name : String
  start : Nat
  stop : Nat
  /-- The precise end of the declaration (doc comment through end of body),
  taken directly from the `.ilean` range. Unlike `stop` (the next
  declaration's start, which overshoots), this ends exactly at the last
  token, so removing `[start, declEnd)` deletes the whole declaration —
  including a multi-paragraph doc comment — without truncating at an
  interior blank line. -/
  declEnd : Nat
  deriving Inhabited

/-- Load every top-level declaration range from the module's `.ilean`, mapped
into character-offset spans against `sourceSrc`. Used everywhere the generator
needs to slice the source by declaration. -/
def loadDeclSpans (root : System.FilePath) (entry : EvalProblemMetadata)
    (sourceSrc : Source) : IO (Array DeclSpan) := do
  let declRanges ← loadIleanDeclRanges root entry.moduleName
  let mut startsBuf : Array (String × Nat × Nat) := #[]
  for ileanEntry in declRanges do
    let off ← sourceSrc.offsetForLineColumn ileanEntry.startLine ileanEntry.startColumn
    let endOff ← sourceSrc.offsetForLineColumn ileanEntry.endLine ileanEntry.endColumn
    startsBuf := startsBuf.push (ileanEntry.name, off, endOff)
  let starts := startsBuf.qsort (fun a b => a.2.1 < b.2.1)
  let mut spans : Array DeclSpan := #[]
  for i in [0:starts.size] do
    let (name, start, declEnd) := starts[i]!
    let stop :=
      if i + 1 < starts.size then starts[i+1]!.2.1
      else findTopLevelEndOffset sourceSrc start
    spans := spans.push { name, start, stop, declEnd }
  return spans

/-- Apply a list of `(start, stop, replacement)` edits to `sourceText`. Edits
are sorted right-to-left and applied in that order so earlier offsets remain
valid. Edits must not overlap. Use `replacement = ""` for a pure deletion. -/
def applyEdits (sourceText : String) (edits : Array (Nat × Nat × String)) : String := Id.run do
  let edits := edits.qsort (fun a b => a.1 > b.1)
  let mut result := sourceText
  for (start, stop, replacement) in edits do
    let src := Source.ofString result
    result := Source.slice src 0 start ++ replacement ++ Source.slice src stop src.size
  return result

/-- The tokens of `line` with comments removed. -/
private def commandTokens (line : String) : Array String :=
  splitWhitespace (stripLineComment (stripSingleLineBlockComments line))

/-- Commands that can be written as `<command> … in <declaration>` to scope
themselves onto a single following declaration. -/
private def scopingCommandKeywords : Array String :=
  #["set_option", "open", "attribute", "include", "omit", "local", "scoped"]

/-- Split `[lowerBound, limit)` into lines, each paired with the tokens it
contributes outside comments. Comment state is carried forward across lines, so
a line inside a multi-line block comment contributes nothing — which is what
makes it recognisable as trivia when the caller walks back over it. -/
private def gapLineTokens (source : Source) (lowerBound limit : Nat) :
    Array (Nat × Array String) := Id.run do
  let mut lines : Array (Nat × Array String) := #[]
  let mut lineStart := lowerBound
  let mut text : String := ""
  let mut depth : Nat := 0
  let mut i := lowerBound
  while i < limit do
    if depth == 0 && Source.startsWithAt source i "--".toList then
      while i < limit && source[i]! != '\n' do
        i := i + 1
    else if Source.startsWithAt source i "/-".toList then
      depth := depth + 1
      i := i + 2
    else if depth > 0 && Source.startsWithAt source i "-/".toList then
      depth := depth - 1
      i := i + 2
    else if source[i]! == '\n' then
      lines := lines.push (lineStart, splitWhitespace text)
      text := ""
      i := i + 1
      lineStart := i
    else
      if depth == 0 then text := text.push source[i]!
      i := i + 1
  return lines.push (lineStart, splitWhitespace text)

/-- Move a removal range's start back over the command prefixes that scope onto
the declaration being removed — `set_option … in`, `open … in`, and friends. A
`.ilean` declaration range begins at the declaration proper, so such a prefix
is not covered by it and would otherwise be stranded with no command to apply
to.

A prefix is recognised by its last token being `in`, and is then followed back
to the line opening the command, so one spread over several lines is consumed
whole, as is one sharing the declaration's own line. Blank and comment-only
lines are crossed, but are only dropped if a prefix is found beyond them.
`lowerBound` is the end of the previous declaration; the search never crosses
it, so text belonging to a declaration we are keeping can never be consumed. -/
def extendOverScopingPrefixes (source : Source) (lowerBound start : Nat) : Nat := Id.run do
  let lines := gapLineTokens source lowerBound start
  let opensCommand : Nat → Bool := fun idx =>
    match (lines[idx]!.2)[0]? with
    | some token => scopingCommandKeywords.contains token
    | none => false
  let mut result := start
  let mut idx := lines.size
  while idx > 0 do
    let (lineStart, tokens) := lines[idx - 1]!
    if tokens.isEmpty then
      -- Trivia is crossed in the hope of a prefix beyond it, and only dropped
      -- if one is found.
      idx := idx - 1
    else if tokens.back? != some "in" then
      return result
    else
      -- Follow the prefix back to the line that opens the command. Stay put
      -- rather than guess if there is no such line within the gap.
      let mut commandIdx := idx - 1
      while commandIdx > 0 && !opensCommand commandIdx do
        commandIdx := commandIdx - 1
      result := if opensCommand commandIdx then lines[commandIdx]!.1 else lineStart
      idx := commandIdx
  return result

/-- Shared core of single- and multi-hole `ChallengeDeps.lean` rendering.

* `keepDeclarations` are the names whose source text we want to *retain*
  (i.e. trusted helpers).
* `protectedRanges` overrides the `.ilean`-derived span for a named decl
  with a precise `(start, stop)` byte range (used by single-hole for the
  extracted theorem and by multi-hole for every hole, where `.ilean`'s
  start-of-next heuristic is wrong for non-final decls). -/
def renderChallengeDepsCore (root : System.FilePath) (entry : EvalProblemMetadata)
    (sourceText : String) (localImports : Array String)
    (keepDeclarations : Std.HashSet String)
    (protectedRanges : Std.HashMap String (Nat × Nat)) :
    IO (Option String) := do
  let mut parts : Array String := #[]
  for imported in localImports do
    let importedPath := moduleSourcePath root imported
    let importedText ← IO.FS.readFile importedPath
    let importedSrc := Source.ofString importedText
    let prelude := importPreludeLength importedSrc
    let afterPrelude := Source.slice importedSrc prelude importedSrc.size
    let body := (stripProblemMarkers afterPrelude).trimAsciiStart.toString
    let body := if !body.isEmpty && !body.endsWith "\n" then body ++ "\n" else body
    if !body.isEmpty then
      parts := parts.push body
  if !keepDeclarations.isEmpty then
    let sourceSrc := Source.ofString sourceText
    let bodyStart := importPreludeLength sourceSrc
    let spans ← loadDeclSpans root entry sourceSrc
    let mut removeRangesRaw : Array (Nat × Nat) := #[]
    -- End of the last declaration we have walked past, so that a removal never
    -- reaches back into the text of the declaration before it.
    let mut previousEnd := bodyStart
    for span in spans do
      -- Delete only the declaration's precise `.ilean` range. Extending to the
      -- next declaration also deletes intervening scoped context commands such
      -- as `variable` and `local notation`, which kept helpers may require.
      let (start, stop) := match protectedRanges[span.name]? with
        | some (s, e) => (s, e)
        | none => (span.start, span.declEnd)
      let declarationText := Source.slice sourceSrc span.start span.declEnd
      if !keepDeclarations.contains span.name && !isSyntaxContextDeclaration declarationText then
        removeRangesRaw := removeRangesRaw.push
          (extendOverScopingPrefixes sourceSrc previousEnd start, stop)
      previousEnd := max previousEnd (max span.declEnd stop)
    let removeRanges := removeRangesRaw.qsort
      (fun a b => a.1 < b.1 || (a.1 == b.1 && a.2 < b.2))
    let mut pieces : Array String := #[]
    let mut cursor := bodyStart
    for (s, e) in removeRanges do
      if e ≤ bodyStart then continue
      let s := if s < bodyStart then bodyStart else s
      if s < cursor then continue
      pieces := pieces.push (Source.slice sourceSrc cursor s)
      cursor := e
    pieces := pieces.push (Source.slice sourceSrc cursor sourceSrc.size)
    let body := (pieces.foldl (· ++ ·) "").trimAsciiStart.toString
    let body := if !body.isEmpty && !body.endsWith "\n" then body ++ "\n" else body
    if !body.isEmpty then
      parts := parts.push body
  if parts.isEmpty then return none
  let joined := "\n".intercalate (parts.toList.map (·.trimAsciiEnd.toString))
  return some ("import Mathlib\n\n" ++ joined ++ "\n")

/-- Render `ChallengeDeps.lean` for a single-hole problem. -/
def renderChallengeDeps (root : System.FilePath) (entry : EvalProblemMetadata)
    (extracted : ExtractedTheorem) (localImports : Array String) :
    IO (Option String) := do
  let sourcePath := moduleSourcePath root entry.moduleName
  if !(← sourcePath.pathExists) then
    throw <| IO.userError
      s!"Source file for module '{entry.moduleName}' not found: {sourcePath}"
  let sourceText ← IO.FS.readFile sourcePath
  let keepDeclarations : Std.HashSet String :=
    extracted.sameModuleDependencies.foldl (·.insert ·) {}
  let sourceSrc := Source.ofString sourceText
  let theoremStart ← sourceSrc.offsetForLineColumn extracted.startLine extracted.startColumn
  let theoremEnd ← sourceSrc.offsetForLineColumn extracted.endLine extracted.endColumn
  let protectedRanges : Std.HashMap String (Nat × Nat) :=
    ({} : Std.HashMap String (Nat × Nat)).insert extracted.declarationName
      (theoremStart, theoremEnd)
  renderChallengeDepsCore root entry sourceText localImports keepDeclarations protectedRanges


/-- For each helper name in `helperNames`, return its enclosing namespace
`_root_`-qualified (the dotted prefix, all components except the last). Used
to inject `open ...` lines so that helpers — declared at root namespace in
`ChallengeDeps.lean` — resolve from unqualified references inside `namespace
Submission`. The `_root_.` qualification is essential: a bare `open Helpers`
inside `namespace Submission` would resolve to `Submission.Helpers` (which
holds the holes), not `_root_.Helpers` (which holds the helpers). Root-level
helpers (no dotted prefix) contribute no `open` — they resolve via `_root_`
automatically. -/
def derivedHelperOpens (helperNames : Std.HashSet String) : Array String := Id.run do
  let mut opens : Array String := #[]
  let mut seen : Std.HashSet String := {}
  for name in helperNames.toList do
    let parts := name.splitOn "."
    if parts.length ≤ 1 then continue
    let prefix' := ".".intercalate (parts.take (parts.length - 1))
    if seen.contains prefix' then continue
    opens := opens.push s!"_root_.{prefix'}"
    seen := seen.insert prefix'
  return opens

/-! ## Python-compatible JSON pretty-printer

`Lean.Json` stores objects in an `RBNode`, which reorders keys
alphabetically/by-tree-shape and disagrees with the insertion order Python's
`json.dumps` uses. To keep `generated/` JSON files reproducible across the
two implementations we build them via an ordered-pair representation and
pretty-print with our own routine. -/

/-- A JSON value that preserves object-key insertion order. -/
inductive OJson where
  | null : OJson
  | bool : Bool → OJson
  | num : Int → OJson
  | str : String → OJson
  | arr : Array OJson → OJson
  | obj : Array (String × OJson) → OJson
  deriving Inhabited

private def hexNat4 (n : Nat) : String :=
  let digits := "0123456789abcdef"
  let nib (k : Nat) : Char := digits.get ⟨k⟩
  String.mk [nib ((n >>> 12) &&& 0xF), nib ((n >>> 8) &&& 0xF),
             nib ((n >>> 4) &&& 0xF), nib (n &&& 0xF)]

/-- Escape a string the way Python's `json.dumps(...)` does with default
`ensure_ascii=True`: ASCII printables stay literal; controls and any
codepoint above U+007F become `\uXXXX` escapes, with codepoints above the BMP
encoded as a UTF-16 surrogate pair. -/
private def escapeJsonString (s : String) : String := Id.run do
  let mut out := ""
  for c in s.toList do
    match c with
    | '"' => out := out ++ "\\\""
    | '\\' => out := out ++ "\\\\"
    | '\n' => out := out ++ "\\n"
    | '\r' => out := out ++ "\\r"
    | '\t' => out := out ++ "\\t"
    | '\x08' => out := out ++ "\\b"
    | '\x0c' => out := out ++ "\\f"
    | _ =>
        let cp := c.toNat
        if cp < 0x20 then
          out := out ++ "\\u" ++ hexNat4 cp
        else if cp < 0x7F then
          out := out.push c
        else if cp ≤ 0xFFFF then
          out := out ++ "\\u" ++ hexNat4 cp
        else
          -- UTF-16 surrogate pair
          let adj := cp - 0x10000
          let hi := 0xD800 + (adj >>> 10)
          let lo := 0xDC00 + (adj &&& 0x3FF)
          out := out ++ "\\u" ++ hexNat4 hi ++ "\\u" ++ hexNat4 lo
  return out

/-- Pretty-print `OJson` matching Python's `json.dumps(value, indent=2)`. -/
partial def OJson.pretty (j : OJson) (indent : Nat := 0) : String :=
  match j with
  | .null => "null"
  | .bool b => if b then "true" else "false"
  | .num n => toString n
  | .str s => "\"" ++ escapeJsonString s ++ "\""
  | .arr xs =>
      if xs.isEmpty then "[]"
      else
        let pad := "".pushn ' ' (indent + 2)
        let closePad := "".pushn ' ' indent
        let parts := xs.toList.map fun x => pad ++ OJson.pretty x (indent + 2)
        "[\n" ++ ",\n".intercalate parts ++ "\n" ++ closePad ++ "]"
  | .obj kvs =>
      if kvs.isEmpty then "{}"
      else
        let pad := "".pushn ' ' (indent + 2)
        let closePad := "".pushn ' ' indent
        let parts := kvs.toList.map fun (k, v) =>
          pad ++ "\"" ++ escapeJsonString k ++ "\": " ++ OJson.pretty v (indent + 2)
        "{\n" ++ ",\n".intercalate parts ++ "\n" ++ closePad ++ "}"

/-- Convenience constructors for `OJson`. -/
def ojStr (s : String) : OJson := .str s
def ojBool (b : Bool) : OJson := .bool b
def ojNat (n : Nat) : OJson := .num (Int.ofNat n)
def ojArr (xs : Array OJson) : OJson := .arr xs
def ojObj (kvs : Array (String × OJson)) : OJson := .obj kvs
def ojStrArr (xs : Array String) : OJson := .arr (xs.map ojStr)

/-! ## Holes metadata -/

/-- Build `holes.json`'s content. Mirrors `build_holes_metadata`. -/
def buildHolesMetadata (root : System.FilePath) (entry : EvalProblemMetadata)
    (extracteds : Array ExtractedTheorem) : IO String := do
  let sourcePath := moduleSourcePath root entry.moduleName
  if !(← sourcePath.pathExists) then
    throw <| IO.userError
      s!"Source file for module '{entry.moduleName}' not found: {sourcePath}"
  let sourceText ← IO.FS.readFile sourcePath
  let src := Source.ofString sourceText
  let mut holes : Array OJson := #[]
  for e in extracteds do
    let startOff ← src.offsetForLineColumn e.startLine e.startColumn
    let endOff ← src.offsetForLineColumn e.endLine e.endColumn
    let bodyRaw := Source.slice src startOff endOff
    let body := (stripProblemMarkers bodyRaw).trim
    holes := holes.push <| ojObj #[
      ("name", ojStr e.declarationName),
      ("basename", ojStr (lastComponentStr e.declarationName)),
      ("kind", ojStr e.kind),
      ("body", ojStr body)
    ]
  let payload := ojObj #[
    ("id", ojStr entry.id),
    ("module", ojStr entry.moduleName),
    ("holes", ojArr holes)
  ]
  return OJson.pretty payload ++ "\n"

/-! ## Rendering workspaces -/

private def renderReadmeLines (entry : EvalProblemMetadata)
    (extracteds : Array ExtractedTheorem) (multiHole : Bool) : Array String := Id.run do
  let mut lines : Array String := #[
    s!"# `{entry.id}`",
    "",
    entry.title,
    "",
    s!"- Problem ID: `{entry.id}`",
    s!"- Test Problem: {if entry.test then "yes" else "no"}",
    s!"- Submitter: {entry.submitter}"
  ]
  if multiHole then
    let holeDescs := extracteds.toList.map fun e => s!"`{e.declarationName}` ({e.kind})"
    lines := lines.push s!"- Holes ({extracteds.size}): {", ".intercalate holeDescs}"
  if let some notes := entry.notes then
    lines := lines.push s!"- Notes: {notes}"
  if let some source := entry.source then
    lines := lines.push s!"- Source: {source}"
  if let some informal := entry.informalSolution then
    lines := lines.push s!"- Informal solution: {informal}"
  let body :=
    if multiHole then
      #[
        "",
        "Do not modify `Challenge.lean` or `Solution.lean`. Those files are part of the",
        "trusted benchmark and fixed by the repository.",
        "",
        "This is a multi-hole problem: the challenge declares multiple `def`s,",
        "`instance`s, and/or `theorem`s as `sorry`. Fill all of them in",
        "`Submission.lean` (under `namespace Submission`) for comparator to accept",
        "your solution.",
        "",
        "Participants may use Mathlib freely. Any helper code not already available in",
        "Mathlib must be inlined into the submission workspace.",
        "",
        "`lake test` runs comparator for this problem. The command expects a comparator",
        "binary in `PATH`, or in the `COMPARATOR_BIN` environment variable."
      ]
    else
      #[
        "",
        "Do not modify `Challenge.lean` or `Solution.lean`. Those files are part of the",
        "trusted benchmark and fixed by the repository.",
        "",
        "Write your solution in `Submission.lean` and any additional local modules under",
        "`Submission/`.",
        "",
        "Participants may use Mathlib freely. Any helper code not already available in",
        "Mathlib must be inlined into the submission workspace.",
        "",
        "Multi-file submissions are allowed through `Submission.lean` and additional local",
        "modules under `Submission/`.",
        "",
        "`lake test` runs comparator for this problem. The command expects a comparator",
        "binary in `PATH`, or in the `COMPARATOR_BIN` environment variable."
      ]
  return lines ++ body

private def lakefileToml (problemId : String) (mathlibDep : DependencySpec)
    (withChallengeDeps : Bool) : String :=
  let challengeDepsLib :=
    if withChallengeDeps then
      "[[lean_lib]]\nname = \"ChallengeDeps\"\n\n"
    else ""
  s!"name = \"{problemId}\"\n" ++
  "testDriver = \"workspace_test\"\n" ++
  "defaultTargets = [\"Challenge\", \"Solution\", \"Submission\"]\n\n" ++
  "[leanOptions]\n" ++
  "autoImplicit = false\n\n" ++
  "[[require]]\n" ++
  s!"name = \"{mathlibDep.name}\"\n" ++
  s!"git = \"{mathlibDep.git}\"\n" ++
  s!"rev = \"{mathlibDep.rev}\"\n\n" ++
  challengeDepsLib ++
  "[[lean_lib]]\nname = \"Challenge\"\n\n" ++
  "[[lean_lib]]\nname = \"Solution\"\n\n" ++
  "[[lean_lib]]\nname = \"Submission\"\n\n" ++
  "[[lean_exe]]\nname = \"workspace_test\"\nroot = \"WorkspaceTest\"\n"

/-! ## Multi-hole rendering -/

private def renderWorkspaceMultiHole (root : System.FilePath) (entry : EvalProblemMetadata)
    (extracteds : Array ExtractedTheorem) (toolchain : String)
    (mathlibDep : DependencySpec) (workspaceTest : String) :
    IO (Array (String × String)) := do
  let sourcePath := moduleSourcePath root entry.moduleName
  if !(← sourcePath.pathExists) then
    throw <| IO.userError
      s!"Source file for module '{entry.moduleName}' not found: {sourcePath}"
  let sourceText ← IO.FS.readFile sourcePath
  let src := Source.ofString sourceText
  -- Hole byte ranges in raw source.
  let mut holesRaw : Array (Nat × Nat × String × String) := #[]
  for e in extracteds do
    let s ← src.offsetForLineColumn e.startLine e.startColumn
    let eo ← src.offsetForLineColumn e.endLine e.endColumn
    holesRaw := holesRaw.push (s, eo, e.declarationName, e.kind)
  let holesWithRanges := holesRaw.qsort (fun a b => a.1 < b.1)
  let mut theoremNames : Array String := #[]
  let mut definitionNames : Array String := #[]
  for (_, _, name, kind) in holesWithRanges do
    if kind == "theorem" then theoremNames := theoremNames.push name
    else definitionNames := definitionNames.push name
  -- Multi-hole problems may carry trusted helper declarations (decls in the
  -- same module that some hole depends on but that are not themselves holes).
  -- Factor them into `ChallengeDeps.lean` so `Submission` and `Solution`
  -- reference the same canonical declaration; otherwise the helpers get
  -- duplicated by the `namespace Submission` wrap and types fail to unify.
  -- A hole that is also another hole's dependency is *not* a helper; the
  -- delegation chain handles it.
  let holeNames : Std.HashSet String :=
    extracteds.foldl (init := {}) fun acc e => acc.insert e.declarationName
  let helperNames : Std.HashSet String :=
    extracteds.foldl (init := {}) fun acc e =>
      e.sameModuleDependencies.foldl
        (fun a n => if holeNames.contains n then a else a.insert n) acc
  -- Load declaration spans from raw source once and validate every declared
  -- helper is actually present (catches stale metadata / source mismatch
  -- early rather than as a confusing Lean build error downstream).
  let spans ← if helperNames.isEmpty then pure (#[] : Array DeclSpan)
              else loadDeclSpans root entry src
  if !helperNames.isEmpty then
    let declNameSet : Std.HashSet String :=
      spans.foldl (init := {}) fun acc s => acc.insert s.name
    -- A helper name `Foo.bar` whose strict prefix `Foo` is *both* a declared
    -- name *and* itself a kept helper is an auto-generated companion of
    -- `Foo` (constructor, field accessor, recursor, ...); stripping `Foo`
    -- from source removes them transparently. Requiring the parent be in
    -- `helperNames` (not just any declared name) prevents an unrelated stale
    -- `Foo.bar.baz` from being silently accepted because some unrelated
    -- `Foo` happens to be declared in the same module.
    let hasKeptHelperParent : String → Bool := fun n =>
      let parts := n.splitOn "."
      (List.range (parts.length - 1)).any fun i =>
        let p := ".".intercalate (parts.take (i + 1))
        helperNames.contains p && declNameSet.contains p
    let missing : Array String := helperNames.toList.foldl (init := #[]) fun acc n =>
      if declNameSet.contains n || hasKeptHelperParent n then acc else acc.push n
    if !missing.isEmpty then
      throw <| IO.userError
        s!"Multi-hole problem '{entry.id}': declared helper dependencies not \
           found in source module: {", ".intercalate missing.toList}"
  let helperRanges : Array (Nat × Nat) :=
    spans.filterMap fun s =>
      if helperNames.contains s.name then some (s.start, s.declEnd)
      else none
  let localImports ← repoLocalImportModules root entry.moduleName
  -- Open the enclosing namespaces of the in-module helpers. When the problem
  -- also pulls trusted deps from imported library modules (`localImports`
  -- non-empty), those deps live in the holes' own enclosing namespace, which
  -- then exists in `ChallengeDeps` at `_root_`; open it too so unqualified
  -- references (e.g. `conwayKnot`) resolve. We must *not* open hole namespaces
  -- when there are no such imports: a namespace containing only holes does not
  -- exist at `_root_` once the holes move under `Submission`, and `open
  -- _root_.<that>` would be an unknown-namespace error (e.g. the all-holes
  -- `jacobian_challenge_*` problems). Duplicates are dropped downstream. -/
  let helperOpens := derivedHelperOpens helperNames ++
    (if localImports.isEmpty then #[] else derivedHelperOpens holeNames)
  -- Render ChallengeDeps via the shared core, passing precise hole ranges so
  -- the helper-extraction slicing knows where the hole bodies live (the
  -- `.ilean`-derived "next decl start" is wrong for non-final holes).
  let mut holeRanges : Std.HashMap String (Nat × Nat) := {}
  for (s, eo, name, _) in holesWithRanges do
    holeRanges := holeRanges.insert name (s, eo)
  let challengeDeps? ←
    renderChallengeDepsCore root entry sourceText localImports helperNames holeRanges
  let hasChallengeDeps := challengeDeps?.isSome
  -- Compute Solution's edit set against raw source: helper removals plus
  -- hole-body replacements (delegations to `Submission.<name>`). Applied in
  -- a single right-to-left pass so all offsets stay valid even if a hole
  -- appears earlier in source than a helper.
  let helperEdits : Array (Nat × Nat × String) :=
    helperRanges.map fun (s, e) => (s, e, "")
  let mut solutionEdits : Array (Nat × Nat × String) := helperEdits
  for (startOff, endOff, fullName, kind) in holesWithRanges do
    let declText := Source.slice src startOff endOff
    let basename := lastComponentStr fullName
    let mut signature ← holeDeclSignature declText basename
    if kind != "theorem" then
      match injectSolutionHoleModifiers signature basename with
      | none =>
          throw <| IO.userError
            s!"Could not anchor `@[reducible] noncomputable` injection in signature for \
               hole '{fullName}'."
      | some rewritten =>
          signature := rewritten
    let declSrc := Source.ofString declText
    let some (_, kwEnd) := Source.findKeywordBasename declSrc
      #["def", "instance", "theorem", "opaque", "lemma", "abbrev", "class", "example"] basename
      | throw <| IO.userError
          s!"Could not locate basename '{basename}' in source decl for hole '{fullName}'."
    let between := Source.slice declSrc kwEnd declSrc.size
    let betweenSrc := Source.ofString between
    let some lastEq := Source.rfind betweenSrc betweenSrc.size ":=".toList
      | throw <| IO.userError s!"Source decl for hole '{fullName}' has no `:=` body marker."
    let statement := Source.slice betweenSrc 0 lastEq
    let sourceArgs := explicitBinderApplicationArgs statement
    let explicitArgs ← match extracteds.find? (fun e => e.declarationName == fullName) with
      | some extracted =>
          let variableNames :=
            variableBlockExplicitNames (extractContextVariables sourceText (some extracted) #[])
          let signatureParams? :=
            if hasBareSorryBody declText then extracted.explicitParameters else none
          match delegationArgs? signatureParams? variableNames sourceArgs with
          | some args => pure args
          | none =>
              throw <| IO.userError
                s!"Could not match the elaborated parameters of hole '{fullName}' against its \
                   source signature; the generated delegation would under-apply it."
      | none => pure sourceArgs
    let applied :=
      if explicitArgs.isEmpty then s!"Submission.{fullName}"
      else s!"Submission.{fullName} " ++ " ".intercalate explicitArgs.toList
    let newDecl := signature ++ applied
    solutionEdits := solutionEdits.push (startOff, endOff, newDecl)
  let solutionText := applyEdits sourceText solutionEdits
  -- Challenge and Submission only need helper removals.
  let helperStripped := applyEdits sourceText helperEdits
  let baseImport := if hasChallengeDeps then "import ChallengeDeps\n\n" else "import Mathlib\n\n"
  let challengeBodyStripped := stripProblemMarkers helperStripped localImports
  let challengeBody :=
    if !(challengeBodyStripped.trimAsciiStart.toString.startsWith "import ") then
      baseImport ++ challengeBodyStripped
    else if hasChallengeDeps then
      injectAfterImports challengeBodyStripped "import ChallengeDeps\n"
    else challengeBodyStripped
  let solutionBody := stripProblemMarkers solutionText localImports
  let solutionBody := injectAfterImports solutionBody "import Submission\n"
  let solutionBody :=
    if hasChallengeDeps then injectAfterImports solutionBody "import ChallengeDeps\n"
    else solutionBody
  -- Submission: source minus helpers, wrapped in `namespace Submission`, with
  -- `Submission.Helpers` and (if present) `ChallengeDeps` imported. When
  -- ChallengeDeps is present, inject one `open <ns>` per distinct helper
  -- enclosing namespace so unqualified helper references inside the wrap
  -- resolve to `_root_.<ns>.<helper>` rather than the (non-existent)
  -- `Submission.<ns>.<helper>`.
  let submissionStripped := stripProblemMarkers helperStripped localImports
  let submissionWithHelpers := injectAfterImports submissionStripped "import Submission.Helpers\n"
  let submissionWithHelpers :=
    if hasChallengeDeps then injectAfterImports submissionWithHelpers "import ChallengeDeps\n"
    else submissionWithHelpers
  let userNamespace := lastComponentStr entry.moduleName
  let submissionBody :=
    wrapBodyInSubmissionNamespace submissionWithHelpers userNamespace (extraOpens := helperOpens)
  -- config
  let mut configPairs : Array (String × OJson) := #[
    ("challenge_module", ojStr "Challenge"),
    ("solution_module", ojStr "Solution"),
    ("theorem_names", ojStrArr theoremNames),
    ("permitted_axioms", ojStrArr fixedAxioms),
    ("enable_nanoda", ojBool false)
  ]
  if !definitionNames.isEmpty then
    configPairs := configPairs.push ("definition_names", ojStrArr definitionNames)
  let config := ojObj configPairs
  let toolchain' := if toolchain.endsWith "\n" then toolchain else toolchain ++ "\n"
  let challenge :=
    if challengeBody.endsWith "\n" then challengeBody else challengeBody ++ "\n"
  let readmeLines := renderReadmeLines entry extracteds (multiHole := true)
  let readme := "\n".intercalate readmeLines.toList ++ "\n"
  let mut files : Array (String × String) := #[
    ("README.md", readme),
    ("lean-toolchain", toolchain'),
    ("lakefile.toml", lakefileToml entry.id mathlibDep (withChallengeDeps := hasChallengeDeps)),
    ("Challenge.lean", challenge),
    ("Solution.lean", solutionBody),
    ("Submission.lean", submissionBody),
    ("Submission/Helpers.lean", "namespace Submission.Helpers\n\nend Submission.Helpers\n"),
    ("WorkspaceTest.lean", workspaceTest),
    ("config.json", OJson.pretty config ++ "\n")
  ]
  if let some cd := challengeDeps? then
    files := files.push ("ChallengeDeps.lean", cd)
  return files

/-! ## Single-hole rendering -/

private def renderWorkspaceSingleHole (root : System.FilePath) (entry : EvalProblemMetadata)
    (extracted : ExtractedTheorem) (toolchain : String) (mathlibDep : DependencySpec)
    (workspaceTest : String) : IO (Array (String × String)) := do
  let sourcePath := moduleSourcePath root entry.moduleName
  let sourceText ← IO.FS.readFile sourcePath
  let src := Source.ofString sourceText
  let theoremName := lastComponentStr extracted.declarationName
  let startOff ← src.offsetForLineColumn extracted.startLine extracted.startColumn
  let endOff ← src.offsetForLineColumn extracted.endLine extracted.endColumn
  let declText := Source.slice src startOff endOff
  let theoremStatement ← extractStatementText entry.id sourcePath declText theoremName
  let localImports ← repoLocalImportModules root entry.moduleName
  let challengeDeps? ← renderChallengeDeps root entry extracted localImports
  let hasChallengeDeps := challengeDeps?.isSome
  let challengeImport :=
    if hasChallengeDeps then "import ChallengeDeps\n\n" else "import Mathlib\n\n"
  let solutionImports :=
    if hasChallengeDeps then "import ChallengeDeps\nimport Submission\n\n"
    else "import Mathlib\nimport Submission\n\n"
  let submissionImports :=
    if hasChallengeDeps then "import ChallengeDeps\nimport Submission.Helpers\n\n"
    else "import Mathlib\nimport Submission.Helpers\n\n"
  let theoremBinderNames := binderIntroducedNames theoremStatement
  let contextUniverseBlock :=
    extractContextUniverses sourceText (some extracted)
  let contextSyntaxBlock :=
    extractContextSyntaxDeclarations sourceText (some extracted)
  let contextLocalSyntaxBlock :=
    extractContextLocalSyntaxDeclarations sourceText (some extracted)
  let contextVariablesBlock :=
    extractContextVariables sourceText (some extracted) theoremBinderNames
  let contextIncludeBlock :=
    extractContextIncludes sourceText (some extracted)
  let signatureParams? :=
    if hasBareSorryBody declText then extracted.explicitParameters else none
  let some solutionArgs := delegationArgs? signatureParams?
      (variableBlockExplicitNames contextVariablesBlock)
      (explicitBinderApplicationArgs theoremStatement)
    | throw <| IO.userError
        s!"Could not match the elaborated parameters of '{extracted.declarationName}' against \
           its source signature; the generated delegation would under-apply it."
  let solutionExact :=
    if solutionArgs.isEmpty then s!"Submission.{theoremName}"
    else s!"Submission.{theoremName} " ++ " ".intercalate solutionArgs.toList
  let includeNamespaces := hasChallengeDeps || !localImports.isEmpty
  let contextOpenBlock ←
    extractContextOpens entry.id sourcePath sourceText (some extracted) includeNamespaces
  let contextOpenBlock :=
    if !contextOpenBlock.isEmpty && !contextOpenBlock.endsWith "\n\n" then
      contextOpenBlock ++ "\n"
    else contextOpenBlock
  let toolchain' := if toolchain.endsWith "\n" then toolchain else toolchain ++ "\n"
  let config := ojObj #[
    ("challenge_module", ojStr "Challenge"),
    ("solution_module", ojStr "Solution"),
    ("theorem_names", ojArr #[ojStr theoremName]),
    ("permitted_axioms", ojStrArr fixedAxioms),
    ("enable_nanoda", ojBool false)
  ]
  let readmeLines := renderReadmeLines entry #[extracted] (multiHole := false)
  let readme := "\n".intercalate readmeLines.toList ++ "\n"
  let challengeFile :=
    challengeImport ++ contextOpenBlock ++ contextUniverseBlock ++
      (if hasChallengeDeps then contextLocalSyntaxBlock else contextSyntaxBlock) ++
      contextVariablesBlock ++ contextIncludeBlock ++
    s!"theorem {theoremName} {theoremStatement} := by\n  sorry\n"
  let solutionFile :=
    solutionImports ++ contextOpenBlock ++ contextUniverseBlock ++ contextLocalSyntaxBlock ++
      contextVariablesBlock ++ contextIncludeBlock ++
    s!"theorem {theoremName} {theoremStatement} := by\n  exact {solutionExact}\n"
  let submissionFile :=
    submissionImports ++ contextOpenBlock ++ contextUniverseBlock ++
      (if hasChallengeDeps then contextLocalSyntaxBlock else contextSyntaxBlock) ++
      contextVariablesBlock ++ contextIncludeBlock ++
    "namespace Submission\n\n" ++
    s!"theorem {theoremName} {theoremStatement} := by\n  sorry\n\n" ++
    "end Submission\n"
  let mut files : Array (String × String) := #[
    ("README.md", readme),
    ("lean-toolchain", toolchain'),
    ("lakefile.toml", lakefileToml entry.id mathlibDep (withChallengeDeps := hasChallengeDeps)),
    ("Challenge.lean", challengeFile),
    ("Solution.lean", solutionFile),
    ("Submission.lean", submissionFile),
    ("Submission/Helpers.lean", "namespace Submission.Helpers\n\nend Submission.Helpers\n"),
    ("WorkspaceTest.lean", workspaceTest),
    ("config.json", OJson.pretty config ++ "\n")
  ]
  if let some cd := challengeDeps? then
    files := files.push ("ChallengeDeps.lean", cd)
  return files

/-- Render every file in a generated workspace. Mirrors `render_workspace`. -/
def renderWorkspace (root : System.FilePath) (entry : EvalProblemMetadata)
    (extracteds : Array ExtractedTheorem) (toolchain : String)
    (mathlibDep : DependencySpec) (workspaceTest : String) :
    IO (Array (String × String)) := do
  let isMultiHole :=
    extracteds.size != 1 || extracteds[0]!.kind != "theorem"
  let baseFiles ←
    if isMultiHole then
      renderWorkspaceMultiHole root entry extracteds toolchain mathlibDep workspaceTest
    else
      renderWorkspaceSingleHole root entry extracteds[0]! toolchain mathlibDep workspaceTest
  let holesJson ← buildHolesMetadata root entry extracteds
  return baseFiles.push ("holes.json", holesJson)

/-! ## Workspace I/O -/

/-- All files under `dir` (recursively), as paths relative to `dir`, posix
style (forward slashes). Skips entries whose first component is in
`ignoredPathNames`. Mirrors `gather_extra_paths`'s `extras` computation. -/
partial def listFilesRecursive (dir : System.FilePath) : IO (Array System.FilePath) := do
  if !(← dir.isDir) then return #[]
  let mut out : Array System.FilePath := #[]
  for entry in (← dir.readDir) do
    if (← entry.path.isDir) then
      let nested ← listFilesRecursive entry.path
      for n in nested do
        out := out.push (entry.fileName / n)
    else
      out := out.push entry.fileName
  return out

/-- Returns the list of paths (relative to `problemDir`) that are present in
the directory but not part of `expectedFiles`, sorted. -/
def gatherExtraPaths (problemDir : System.FilePath) : IO (Array System.FilePath) := do
  if !(← problemDir.pathExists) then return #[]
  let all ← listFilesRecursive problemDir
  let all := all.qsort (fun a b => a.toString < b.toString)
  let expected : Std.HashSet String := expectedFiles.foldl (·.insert ·) {}
  let mut out : Array System.FilePath := #[]
  for p in all do
    let posix := "/".intercalate (p.components.map id)
    let firstComp := p.components.head!
    if ignoredPathNames.contains firstComp then continue
    if expected.contains posix then continue
    out := out.push p
  return out

/-- Write the rendered files into `problemDir`, replacing any stale content.
Mirrors `write_workspace`. -/
def writeWorkspace (problemDir : System.FilePath)
    (files : Array (String × String)) : IO Unit := do
  IO.FS.createDirAll problemDir
  let provided : Std.HashSet String := files.foldl (fun acc (p, _) => acc.insert p) {}
  for relPath in expectedFiles do
    if provided.contains relPath then continue
    let dest := problemDir / relPath
    if (← dest.pathExists) then
      let info ← dest.metadata
      if info.type == .file then
        IO.FS.removeFile dest
  for extra in (← gatherExtraPaths problemDir) do
    IO.FS.removeFile (problemDir / extra)
  for (relPath, content) in files do
    let dest := problemDir / relPath
    if let some parent := dest.parent then
      IO.FS.createDirAll parent
    IO.FS.writeFile dest content

/-- Return a list of mismatches between expected files and what's on disk.
Mirrors `check_workspace`. -/
def checkWorkspace (problemDir : System.FilePath) (relToRoot : String)
    (files : Array (String × String)) : IO (Array String) := do
  let mut mismatches : Array String := #[]
  let provided : Std.HashSet String := files.foldl (fun acc (p, _) => acc.insert p) {}
  for relPath in expectedFiles do
    if provided.contains relPath then continue
    let dest := problemDir / relPath
    if (← dest.pathExists) then
      mismatches := mismatches.push s!"unexpected {relToRoot}/{relPath}"
  for (relPath, expectedContent) in files do
    let dest := problemDir / relPath
    if !(← dest.pathExists) then
      mismatches := mismatches.push s!"missing {relToRoot}/{relPath}"
      continue
    let info ← dest.metadata
    if info.type != .file then
      mismatches := mismatches.push s!"missing {relToRoot}/{relPath}"
      continue
    let actual ← IO.FS.readFile dest
    if actual != expectedContent then
      mismatches := mismatches.push s!"stale {relToRoot}/{relPath}"
  for extra in (← gatherExtraPaths problemDir) do
    let posix := "/".intercalate (extra.components.map id)
    mismatches := mismatches.push s!"unexpected {relToRoot}/{posix}"
  return mismatches

/-! ## Validate hole shape -/

/-- Sanity-check that each manifest hole appears as a top-level
`theorem/def/instance/opaque` declaration in its source module. Mirrors
`validate_hole_shape`. -/
def validateHoleShape (root : System.FilePath) (entries : Array EvalProblemMetadata) :
    IO Unit := do
  for entry in entries do
    let sourcePath := moduleSourcePath root entry.moduleName
    if !(← sourcePath.pathExists) then
      throw <| IO.userError
        s!"Source file for module '{entry.moduleName}' not found: {sourcePath}"
    let sourceText ← IO.FS.readFile sourcePath
    let src := Source.ofString sourceText
    for hole in entry.holes do
      let basename := lastComponentStr hole
      match Source.findKeywordBasename src #["theorem", "opaque", "def", "instance"] basename with
      | some _ => continue
      | none =>
          let display :=
            let sp := sourcePath.toString
            let rp := root.toString ++ "/"
            if sp.startsWith rp then sp.drop rp.length |>.toString else sp
          throw <| IO.userError
            s!"Problem '{entry.id}' lists hole '{basename}' which is not declared as a top-level theorem/def/instance in {display}."

/-! ## Sync unknown / index -/

/-- Remove (or report) workspace directories under `generated/` that aren't in
`selectedIds`. Mirrors `sync_unknown_problem_dirs`. -/
def syncUnknownProblemDirs (root : System.FilePath) (selectedIds : Std.HashSet String)
    (check : Bool) : IO (Array String) := do
  let generated := root / "generated"
  IO.FS.createDirAll generated
  let mut mismatches : Array String := #[]
  let entries ← generated.readDir
  let entries := entries.qsort (fun a b => a.fileName < b.fileName)
  for e in entries do
    if e.fileName == "index.json" then continue
    if !(← e.path.isDir) then continue
    if selectedIds.contains e.fileName then continue
    if check then
      mismatches := mismatches.push s!"unexpected generated directory generated/{e.fileName}"
    else
      IO.FS.removeDirAll e.path
  return mismatches

/-- Write or check `generated/index.json`. Mirrors `write_or_check_index`. -/
def writeOrCheckIndex (root : System.FilePath) (entries : Array OJson) (check : Bool) :
    IO (Array String) := do
  let generated := root / "generated"
  let indexPath := generated / "index.json"
  let content := OJson.pretty (ojArr entries) ++ "\n"
  if check then
    if !(← indexPath.pathExists) then
      return #["missing generated/index.json"]
    let actual ← IO.FS.readFile indexPath
    if actual != content then
      return #["stale generated/index.json"]
    return #[]
  IO.FS.createDirAll generated
  IO.FS.writeFile indexPath content
  return #[]

/-! ## Generate orchestrator -/

/-- Main `generate` entry point. Mirrors `scripts/generate_projects.py:generate`. -/
def generate (root : System.FilePath) (selectedProblemId : Option String) (check : Bool) :
    IO Unit := do
  let problems ← loadManifest root
  let selectedProblems ←
    match selectedProblemId with
    | some id =>
        let filtered := problems.filter (·.id == id)
        if filtered.isEmpty then
          throw <| IO.userError s!"Unknown problem id '{id}'"
        pure filtered
    | none =>
        validateManifestAgainstInventory root problems
        let selectedIds : Std.HashSet String :=
          problems.foldl (fun acc p => acc.insert p.id) {}
        let mismatches ← syncUnknownProblemDirs root selectedIds check
        if !mismatches.isEmpty then
          throw <| IO.userError <| "\n".intercalate mismatches.toList
        pure problems
  validateHoleShape root selectedProblems
  let toolchain ← IO.FS.readFile (root / "lean-toolchain")
  let mathlibDep ← loadRootMathlibDependency root
  buildExtractor root selectedProblems
  let workspaceTest ← loadWorkspaceTestTemplate root
  let mut indexEntries : Array OJson := #[]
  let mut mismatches : Array String := #[]
  for entry in selectedProblems do
    let mut extracteds : Array ExtractedTheorem := #[]
    for hole in entry.holes do
      let e ← extractOne root entry hole
      extracteds := extracteds.push e
    let files ← renderWorkspace root entry extracteds toolchain mathlibDep workspaceTest
    let problemDir := root / "generated" / entry.id
    let relDisplay := s!"generated/{entry.id}"
    if check then
      mismatches := mismatches ++ (← checkWorkspace problemDir relDisplay files)
    else
      writeWorkspace problemDir files
    indexEntries := indexEntries.push <| ojObj #[
      ("id", ojStr entry.id),
      ("title", ojStr entry.title),
      ("test", ojBool entry.test),
      ("submitter", ojStr entry.submitter),
      ("module", ojStr entry.moduleName),
      ("holes", ojStrArr entry.holes),
      ("generated_path", ojStr s!"generated/{entry.id}")
    ]
  if selectedProblemId.isNone then
    mismatches := mismatches ++ (← writeOrCheckIndex root indexEntries check)
  if !mismatches.isEmpty then
    throw <| IO.userError <| "\n".intercalate mismatches.toList
  if check then
    IO.println "Generated workspaces are up to date."
  else
    IO.println s!"Generated {selectedProblems.size} problem workspace(s)."

end EvalTools
