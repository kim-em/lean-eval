import Mathlib
import EvalTools.Markers

namespace LeanEval

/-!
The declarations in this module are the human-authored source of truth for benchmark
statements. The generator reads declarations marked with `@[eval_problem]` and emits
independent comparator workspaces from these shared source files, so benchmark authors
do not need to hand-maintain per-problem packages.
-/

@[eval_problem]
theorem two_plus_two_eq_four : (2 : Nat) + 2 = 4 := by
  sorry

@[eval_problem]
theorem list_append_singleton_length :
    (([1, 2] : List Nat).append [3]).length = 3 := by
  sorry

/--
error: The theorem `LeanEval.eval_problem_manifest_guard` is marked with @[eval_problem], but `manifests/problems.toml` has no matching `theorem = ...` entry.
Add a corresponding problem entry to the manifest.
-/
#guard_msgs in
@[eval_problem]
theorem eval_problem_manifest_guard : (1 : Nat) = 1 := by
  rfl

/--
error: The theorem `LeanEval.eval_problem_implicit_binder_guard` uses implicit value parameters that are not inferable from the explicit hypotheses or the conclusion, which @[eval_problem] does not allow.
Generated benchmark wrappers must be able to call the theorem by ordinary application, without named arguments or `@`.
Keep implicit type parameters like `{α : Type*}` and instance parameters like `[Field K]`.
For benchmark inputs that are not recoverable from later explicit binders, use explicit binders `(x : τ)` instead of implicit ones `{x : τ}`.
Non-inferable implicit binders:
- `n` : ℕ (implicit)
-/
#guard_msgs in
@[eval_problem]
theorem eval_problem_implicit_binder_guard {n : Nat} [NeZero n] : True := by
  trivial

/--
error: The theorem `LeanEval.eval_problem_inferable_implicit_guard` is marked with @[eval_problem], but `manifests/problems.toml` has no matching `theorem = ...` entry.
Add a corresponding problem entry to the manifest.
-/
#guard_msgs in
@[eval_problem]
theorem eval_problem_inferable_implicit_guard {n : Nat} (h : n = n) : n = n := by
  exact h

@[eval_problem]
theorem ci_smoke_2026_04_30 : True := by trivial

def starterNumber : Nat := 4

end LeanEval
