import Mathlib.Algebra.Group.End
import Mathlib.Combinatorics.SimpleGraph.Maps
import Mathlib.Computability.TuringMachine.PostTuringMachine
import Mathlib.Data.List.FinRange
import Mathlib.Data.Nat.Log
import Mathlib.GroupTheory.QuotientGroup.Basic
import Mathlib.GroupTheory.Solvable
import EvalTools.Markers

/-!
# Graph isomorphism in quasipolynomial time, assuming Schreier's hypothesis

Statement of Babai's result that graph isomorphism is decidable
in quasipolynomial time, conditional on Schreier's hypothesis
that every finite simple group has solvable outer automorphism group.
The proof of Schreier's hypothesis requires the classification
of finite simple groups; Babai's result is stated in conditional
form so that the proof can be formalized without formalizing
the classification of finite simple groups.
-/

namespace BabaiGI

/-! ## The group-theoretic hypothesis -/

/-- For a multiplicative group `G`, `MulAut G` is Mathlib's built-in
    automorphism group. The inner automorphism group is the image of
    the conjugation homomorphism. -/
def innerAut (G : Type*) [Group G] : Subgroup (MulAut G) :=
  (MulAut.conj (G := G)).range

/-- Inner automorphisms form a normal subgroup of the automorphism group.
    We need this fact because the outer automorphism group is defined
    to be the quotient `MulAut G ⧸ innerAut G`. By declaring this
    fact to be an  `instance` we enable Lean to use it automatically. -/
instance innerAutNormal (G : Type*) [Group G] : (innerAut G).Normal where
  conj_mem φ hφ ψ := by
    rcases hφ with ⟨g, rfl⟩
    refine ⟨ψ g, ?_⟩
    apply MulEquiv.ext
    intro x
    simp only [MulAut.conj_apply, MulAut.mul_apply, map_mul, map_inv,
      MulAut.apply_inv_self]

/-- The outer automorphism group Aut(G) / Inn(G). -/
abbrev OuterAut (G : Type*) [Group G] :=
  MulAut G ⧸ innerAut G

/-- Schreier's hypothesis: every finite simple group has solvable outer
    automorphism group. -/
def SchreierHypothesis : Prop :=
  ∀ (G : Type) [Group G] [Finite G] [IsSimpleGroup G],
    Group.IsSolvable (OuterAut G)

/-! ## Graphs as finite binary input strings -/

/-- The full adjacency matrix as a list of bits, in row-major order.
    For each pair of vertices, `decide` converts the adjacency proposition
    into a Boolean value. -/
def adjacencyBits {n : ℕ} (G : SimpleGraph (Fin n))
    [DecidableRel G.Adj] : List Bool :=
  (List.finRange n).flatMap fun i =>
    (List.finRange n).map fun j => decide (G.Adj i j)

/-- Encode a pair of graphs G (with n vertices) and H (with m vertices)
    as `1^n 0 matrix(G) 1^m 0 matrix(H)`.
    The length is `n + 1 + n^2 + m + 1 + m^2`. -/
def encodePairOfGraphs {n m : ℕ} (G : SimpleGraph (Fin n))
    (H : SimpleGraph (Fin m)) [DecidableRel G.Adj]
    [DecidableRel H.Adj] : List Bool :=
  List.replicate n true ++ [false] ++ adjacencyBits G ++
    List.replicate m true ++ [false] ++ adjacencyBits H

/-- Graph isomorphism is already in Mathlib as Nonempty (G ≃g H),
    but we want to represent it as a language of binary strings.
    A yes-instance must be an encoding of a pair of graphs,
    and the graphs must be isomorphic. -/
def AreIsomorphicGraphs (input : List Bool) : Prop :=
  ∃ (n m : ℕ) (G : SimpleGraph (Fin n)) (H : SimpleGraph (Fin m))
      (adjG : DecidableRel G.Adj) (adjH : DecidableRel H.Adj),
    input = @encodePairOfGraphs n m G H adjG adjH ∧ Nonempty (G ≃g H)

/-! ## A fixed finite-state machine and its actual transition count -/

/-- Three tape symbols: `none` is blank; `some false` and `some true` are bits. -/
abbrev Symbol := Option Bool

/-- A deterministic machine with states `0, ..., numStates`. The extra state
    ensures that the state set is nonempty. Technically, the number of states
    is `numStates + 1` but we abuse terminology slightly for brevity. -/
abbrev Machine (numStates : ℕ) :=
  Turing.TM0.Machine Symbol (Fin (numStates + 1))

/-- A machine configuration consists of a state and a tape. -/
abbrev Configuration (numStates : ℕ) :=
  Turing.TM0.Cfg Symbol (Fin (numStates + 1))

/-- `runFor M budget c` means: start in configuration `c`, follow `M`
    for (at most) `budget` transitions, and return the configuration reached.
    Stop early if the machine halts. -/
def runFor {numStates : ℕ} (M : Machine numStates) :
    ℕ → Configuration numStates → Configuration numStates
  | 0, c => c
  | t + 1, c =>
      match Turing.TM0.step M c with
      | none => c
      | some c' => runFor M t c'

/-- `RunsAndOutputs M input budget answer` means: the machine `M`,
     when run on the input `input` for (at most) `budget` transitions,
     halts and leaves the output bit `answer` under its head.
     A blank symbol is not an output bit. -/
def RunsAndOutputs {numStates : ℕ} (M : Machine numStates) (input : List Bool)
    (budget : ℕ) (answer : Bool) : Prop :=
  let start : Configuration numStates :=
    Turing.TM0.init (input.map fun bit => (some bit : Symbol))
  let finish := runFor M budget start
  Turing.TM0.step M finish = none ∧ finish.Tape.1 = some answer

/-! ## Quasipolynomial time and the conditional theorem -/

/-- It suffices to consider quasipolynomials of the form
    `2 ^ (constFactor * (Nat.log 2 (N + 2) + 1) ^ exponent)`
    where `constFactor`, `exponent`, and `N` are natural numbers.
    `Nat.log 2` is the floor of the base-two logarithm.
    The + 2 and + 1 shifts accommodate inputs of length zero or one. -/
def Quasipolynomial (constFactor exponent N : ℕ) : ℕ :=
  2 ^ (constFactor * (Nat.log 2 (N + 2) + 1) ^ exponent)

/-- This is Babai's result, stated unconditionally.
    A deterministic Turing machine decides graph isomorphism
    in quasipolynomial time on every input. -/
def GraphIsomorphismIsQuasipolynomial : Prop :=
  ∃ (numStates : ℕ) (M : Machine numStates) (constFactor exponent : ℕ),
    0 < constFactor ∧ 0 < exponent ∧
      ∀ input : List Bool, ∃ answer : Bool,
        RunsAndOutputs M input (Quasipolynomial constFactor exponent input.length) answer ∧
          (answer = true ↔ AreIsomorphicGraphs input)

/-- This is Babai's result, with Schreier's hypothesis as an explicit premise. -/
@[eval_problem]
theorem Schreier_implies_graph_isomorphism_quasipolynomial :
    SchreierHypothesis → GraphIsomorphismIsQuasipolynomial := by
    intro hSchreier
    sorry

end BabaiGI
