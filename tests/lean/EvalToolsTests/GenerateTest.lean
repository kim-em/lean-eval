import EvalTools.Generate

open EvalTools

set_option autoImplicit false

private def assertEq {α : Type} [BEq α] [Repr α] (label : String)
    (actual expected : α) : Option String :=
  if actual == expected then none
  else some s!"{label}: expected {repr expected}, got {repr actual}"

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

def main : IO UInt32 := do
  let passes ← IO.mkRef 0
  let fails ← IO.mkRef 0

  check "extractStatementText accepts a direct sorry body" passes fails do
    let declaration :=
      "theorem target (n : Nat) :\n" ++
      "    ∃ m, n ≤ m :=\n" ++
      "  sorry"
    let actual ← extractStatementText "direct-sorry" "Demo.lean" declaration "target"
    pure <| assertEq "statement" actual "(n : Nat) :\n    ∃ m, n ≤ m"

  check "extractStatementText accepts trivia before by" passes fails do
    let declaration :=
      "theorem target : True := /- proof starts here -/\n" ++
      "  by\n" ++
      "    sorry"
    let actual ← extractStatementText "trivia-before-by" "Demo.lean" declaration "target"
    pure <| assertEq "statement" actual ": True"

  check "extractStatementText ignores body-like text in the statement" passes fails do
    let declaration :=
      "theorem target :\n" ++
      "    let marker := \"fake := by and := sorry\"\n" ++
      "    marker.length = 24 :=\n" ++
      "  sorry"
    let actual ← extractStatementText "body-like-text" "Demo.lean" declaration "target"
    pure <| assertEq "statement" actual
      ":\n    let marker := \"fake := by and := sorry\"\n    marker.length = 24"

  check "extractStatementText ignores nested proof assignments" passes fails do
    let declaration :=
      "theorem target (h : True := by trivial) : True := by\n" ++
      "  have nested : True := sorry"
    let actual ← extractStatementText "nested-assignment" "Demo.lean" declaration "target"
    pure <| assertEq "statement" actual "(h : True := by trivial) : True"

  check "extractStatementText handles quote characters" passes fails do
    let declaration :=
      "theorem target : ('\"' : Char) = '\"' := by sorry"
    let actual ← extractStatementText "char-literal" "Demo.lean" declaration "target"
    pure <| assertEq "statement" actual ": ('\"' : Char) = '\"'"

  check "extractContextSyntaxDeclarations respects scope" passes fails do
    let source :=
      "section\n" ++
      "local notation \"closed\" => Nat\n" ++
      "end\n" ++
      "namespace Demo\n" ++
      "local notation:arg \"ℝ^\" n:arg => EuclideanSpace ℝ (Fin n)\n" ++
      "theorem target : True := by sorry\n" ++
      "end Demo\n"
    let extracted : ExtractedTheorem := {
      declarationName := "Demo.target"
      module := "Demo"
      startLine := 6, startColumn := 0
      endLine := 6, endColumn := 32
      sameModuleDependencies := #[]
      kind := "theorem"
    }
    let context := extractContextSyntaxDeclarations source (some extracted)
    pure <| assertEq "active notation kept" ((context.find? "local notation:arg").isSome) true
      |>.or (assertEq "closed notation dropped" ((context.find? "closed").isSome) false)

  -- Regression for https://github.com/leanprover/lean-eval/pull/467:
  -- Mathlib-style copyright headers precede imports. The generator must drop
  -- both the header and imports before copying trusted helpers into
  -- `ChallengeDeps.lean`; otherwise `import EvalTools.Markers` leaks into the
  -- standalone workspace's trusted-helper path.
  check "importPreludeLength skips a Mathlib copyright header" passes fails do
    let prelude :=
      "/-\n" ++
      "Copyright (c) 2026 Example. All rights reserved.\n" ++
      "Released under Apache 2.0 license as described in the file LICENSE.\n" ++
      "Authors: Example Author\n" ++
      "-/\n" ++
      "import Mathlib\n" ++
      "import EvalTools.Markers\n"
    let body := "\nnamespace Demo\n\ndef trustedHelper : Nat := 1\n"
    let source := Source.ofString (prelude ++ body)
    let afterPrelude := Source.slice source (importPreludeLength source) source.size
    pure <| assertEq "body after prelude" afterPrelude body

  check "importPreludeLength handles a nested copyright header" passes fails do
    let prelude :=
      "/-\n" ++
      "Copyright (c) 2026 Example. All rights reserved.\n" ++
      "/- nested block comment -/\n" ++
      "-/\n" ++
      "import Mathlib\n" ++
      "import EvalTools.Markers\n" ++
      "\n"
    let body := "namespace Demo\n\ndef trustedHelper : Nat := 1\n"
    let source := Source.ofString (prelude ++ body)
    let afterPrelude :=
      (Source.slice source (importPreludeLength source) source.size).trimAsciiStart.toString
    pure <| assertEq "body after prelude" afterPrelude body

  -- A module doc comment after the imports belongs to the source body and must
  -- not be mistaken for a copyright header.
  check "importPreludeLength preserves a block comment after imports" passes fails do
    let prelude := "import Mathlib\n\n"
    let body := "/-! Module documentation. -/\n\nnamespace Demo\n"
    let source := Source.ofString (prelude ++ body)
    let afterPrelude :=
      (Source.slice source (importPreludeLength source) source.size).trimAsciiStart.toString
    pure <| assertEq "body after prelude" afterPrelude body

  check "importPreludeLength skips comments between imports" passes fails do
    let prelude :=
      "-- Copyright (c) 2026 Example\n" ++
      "import Mathlib\n" ++
      "/- The marker import is repository-local. -/\n" ++
      "import EvalTools.Markers\n"
    let body := "\nnamespace Demo\n"
    let source := Source.ofString (prelude ++ body)
    let afterPrelude := Source.slice source (importPreludeLength source) source.size
    pure <| assertEq "body after prelude" afterPrelude body

  check "wrapBodyInSubmissionNamespace handles a nested header" passes fails do
    let source :=
      "/-\n" ++
      "Copyright (c) 2026 Example.\n" ++
      "/- nested block comment -/\n" ++
      "-/\n" ++
      "import Mathlib\n\n" ++
      "namespace Demo\n\ndef target : Nat := 1\n\nend Demo\n"
    let wrapped := wrapBodyInSubmissionNamespace source "Demo"
    pure <| assertEq "submission namespace inserted after header"
      ((wrapped.find? "\nnamespace Submission\n\nnamespace Demo\n").isSome) true

  check "isScopedOpenLine: open Foo is top-level" passes fails do
    pure <| assertEq "scoped" (isScopedOpenLine "open Foo") false

  check "isScopedOpenLine: open scoped Classical is top-level" passes fails do
    pure <| assertEq "scoped" (isScopedOpenLine "open scoped Classical") false

  check "isScopedOpenLine: open Foo in is scoped" passes fails do
    pure <| assertEq "scoped" (isScopedOpenLine "open Foo in") true

  check "isScopedOpenLine: open Foo in body is scoped" passes fails do
    pure <| assertEq "scoped" (isScopedOpenLine "open Foo in rfl") true

  check "isScopedOpenLine: open scoped Classical in is scoped" passes fails do
    pure <| assertEq "scoped" (isScopedOpenLine "open scoped Classical in") true

  check "isScopedOpenLine: open Foo.In is top-level" passes fails do
    pure <| assertEq "scoped" (isScopedOpenLine "open Foo.In") false

  check "isScopedOpenLine: non-open line is not scoped" passes fails do
    pure <| assertEq "scoped" (isScopedOpenLine "theorem foo : True := trivial") false

  -- A trailing `--` comment that happens to contain the word `in` must not
  -- cause a top-level `open` to be misclassified as scoped.
  check "isScopedOpenLine: trailing comment with 'in' is not scoped" passes fails do
    pure <| assertEq "scoped"
      (isScopedOpenLine "open Foo -- used in later declarations") false

  check "isScopedOpenLine: real scoped open with comment is scoped" passes fails do
    pure <| assertEq "scoped"
      (isScopedOpenLine "open Foo in expr -- comment") true

  -- Block comment containing `in` must not trigger a false positive.
  check "isScopedOpenLine: block comment with 'in' is not scoped" passes fails do
    pure <| assertEq "scoped"
      (isScopedOpenLine "open Foo /- mentions in here -/") false

  check "isScopedOpenLine: nested block comment is stripped" passes fails do
    pure <| assertEq "scoped"
      (isScopedOpenLine "open Foo /- outer /- inner in -/ still in -/") false

  check "isScopedOpenLine: real scoped open with block comment is scoped" passes fails do
    pure <| assertEq "scoped"
      (isScopedOpenLine "open Foo /- note -/ in expr") true

  -- Regression for https://github.com/leanprover/lean-eval/issues/277:
  -- `open Classical in` inside an earlier def body must not leak into the
  -- collected context-open block.
  check "extractContextOpens skips open … in inside def bodies" passes fails do
    let source :=
      "import Mathlib\n" ++
      "namespace LeanEval.Algebra\n" ++
      "open Polynomial\n" ++
      "\n" ++
      "noncomputable def sturmAux : Nat → Nat\n" ++
      "  | 0       => 0\n" ++
      "  | (n + 1) =>\n" ++
      "    open Classical in\n" ++
      "    if n = 0 then 1 else sturmAux n\n" ++
      "\n" ++
      "theorem target : True := trivial\n" ++
      "end LeanEval.Algebra\n"
    let extracted : ExtractedTheorem := {
      declarationName := "LeanEval.Algebra.target"
      module := "LeanEval.Algebra"
      startLine := 11, startColumn := 0
      endLine := 11, endColumn := 30
      sameModuleDependencies := #[]
      kind := "theorem"
    }
    let block ← extractContextOpens "demo" "demo.lean" source (some extracted)
      (includeNamespaces := true)
    -- The block should mention top-level opens but not the scoped `open Classical in`.
    let hasOpenPolynomial := (block.find? "open Polynomial").isSome
    let hasOpenClassicalIn := (block.find? "open Classical in").isSome
    pure <| assertEq "top-level open kept" hasOpenPolynomial true |>.or
      (assertEq "scoped open dropped" hasOpenClassicalIn false)

  -- Multi-line scoped open: `open Foo` on one line, `in` on the next.
  -- The whole thing is scoped to one command and must not be hoisted out.
  check "extractContextOpens skips multi-line open … in" passes fails do
    let source :=
      "import Mathlib\n" ++
      "namespace Demo\n" ++
      "open Polynomial\n" ++
      "\n" ++
      "noncomputable def helper : Nat :=\n" ++
      "  open Classical\n" ++
      "    in if 0 = 0 then 1 else 2\n" ++
      "\n" ++
      "theorem target : True := trivial\n" ++
      "end Demo\n"
    let extracted : ExtractedTheorem := {
      declarationName := "Demo.target"
      module := "Demo"
      startLine := 9, startColumn := 0
      endLine := 9, endColumn := 30
      sameModuleDependencies := #[]
      kind := "theorem"
    }
    let block ← extractContextOpens "demo" "demo.lean" source (some extracted)
      (includeNamespaces := true)
    let hasOpenPolynomial := (block.find? "open Polynomial").isSome
    let hasOpenClassical := (block.find? "open Classical").isSome
    pure <| assertEq "top-level open kept" hasOpenPolynomial true |>.or
      (assertEq "scoped open (multi-line) dropped" hasOpenClassical false)

  -- A real top-level `open` whose trailing comment mentions `in` must be kept.
  check "extractContextOpens keeps top-level open with 'in' in comment" passes fails do
    let source :=
      "import Mathlib\n" ++
      "namespace Demo\n" ++
      "open Polynomial -- used in later declarations\n" ++
      "\n" ++
      "theorem target : True := trivial\n" ++
      "end Demo\n"
    let extracted : ExtractedTheorem := {
      declarationName := "Demo.target"
      module := "Demo"
      startLine := 5, startColumn := 0
      endLine := 5, endColumn := 30
      sameModuleDependencies := #[]
      kind := "theorem"
    }
    let block ← extractContextOpens "demo" "demo.lean" source (some extracted)
      (includeNamespaces := true)
    let hasOpenPolynomial := (block.find? "open Polynomial").isSome
    pure <| assertEq "top-level open with 'in' comment kept" hasOpenPolynomial true

  check "injectSolutionHoleModifiers: plain def gains both modifiers" passes fails do
    pure <| assertEq "rewritten"
      (injectSolutionHoleModifiers "def foo : Nat := " "foo")
      (some "@[reducible] noncomputable def foo : Nat := ")

  check "injectSolutionHoleModifiers: existing noncomputable is folded" passes fails do
    pure <| assertEq "rewritten"
      (injectSolutionHoleModifiers "noncomputable def foo : Nat := " "foo")
      (some "@[reducible] noncomputable def foo : Nat := ")

  check "injectSolutionHoleModifiers: instance with doc comment" passes fails do
    pure <| assertEq "rewritten"
      (injectSolutionHoleModifiers
        "/-- doc -/\nnoncomputable instance instFoo : Inhabited Nat := " "instFoo")
      (some "/-- doc -/\n@[reducible] noncomputable instance instFoo : Inhabited Nat := ")

  -- The word `noncomputable` at the end of a doc comment is not a modifier
  -- and must not be stripped.
  check "injectSolutionHoleModifiers: doc comment mentioning noncomputable" passes fails do
    pure <| assertEq "rewritten"
      (injectSolutionHoleModifiers "/-- might be noncomputable -/\ndef foo : Nat := " "foo")
      (some "/-- might be noncomputable -/\n@[reducible] noncomputable def foo : Nat := ")

  check "injectSolutionHoleModifiers: no def/instance/abbrev anchor" passes fails do
    pure <| assertEq "rewritten"
      (injectSolutionHoleModifiers "theorem foo : True := " "foo")
      none

  -- Regression for https://github.com/leanprover/lean-eval/issues/421:
  -- a top-level `universe` command in scope at the theorem must be re-emitted,
  -- or the reconstructed single-hole `Challenge.lean` slice fails with
  -- `unknown universe level`.
  check "extractContextUniverses keeps top-level universe in scope" passes fails do
    let source :=
      "import Mathlib\n" ++
      "universe v u\n" ++
      "def IsTopos (E : Type u) : Prop := True\n" ++
      "theorem target {E : Type u} : True := trivial\n"
    let extracted : ExtractedTheorem := {
      declarationName := "target"
      module := "Demo"
      startLine := 4, startColumn := 0
      endLine := 4, endColumn := 40
      sameModuleDependencies := #[]
      kind := "theorem"
    }
    let block := extractContextUniverses source (some extracted)
    pure <| assertEq "universe line emitted" ((block.find? "universe v u").isSome) true

  -- A `universe` declared inside a `section`/`namespace` that has already been
  -- closed before the theorem is out of scope and must not be re-emitted.
  check "extractContextUniverses drops out-of-scope universe" passes fails do
    let source :=
      "import Mathlib\n" ++
      "section\n" ++
      "universe w\n" ++
      "end\n" ++
      "theorem target : True := trivial\n"
    let extracted : ExtractedTheorem := {
      declarationName := "target"
      module := "Demo"
      startLine := 5, startColumn := 0
      endLine := 5, endColumn := 30
      sameModuleDependencies := #[]
      kind := "theorem"
    }
    let block := extractContextUniverses source (some extracted)
    pure <| assertEq "out-of-scope universe dropped" block ""

  -- An indented top-level declaration following `universe` is a fresh command,
  -- not a continuation of the binder list, and must not be absorbed into the
  -- emitted block (which would produce malformed `Challenge.lean`).
  check "extractContextUniverses stops at indented declaration" passes fails do
    let source :=
      "import Mathlib\n" ++
      "universe u\n" ++
      "  def Foo := Type u\n" ++
      "theorem target : True := trivial\n"
    let extracted : ExtractedTheorem := {
      declarationName := "target"
      module := "Demo"
      startLine := 4, startColumn := 0
      endLine := 4, endColumn := 30
      sameModuleDependencies := #[]
      kind := "theorem"
    }
    let block := extractContextUniverses source (some extracted)
    pure <| assertEq "universe line only" block "universe u\n\n"

  let passCount ← passes.get
  let failCount ← fails.get
  IO.println s!"\n{passCount} passed, {failCount} failed."
  return if failCount == 0 then 0 else 1
