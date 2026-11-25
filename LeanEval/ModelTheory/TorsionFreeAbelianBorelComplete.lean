import TauCeti.ModelTheory.Algebra.Group.Basic
import TauCeti.ModelTheory.RelationalConfiguration.GraphClass
import TauCeti.ModelTheory.RelationalConfiguration.Functional.BorelComplete
import EvalTools.Markers

/-!
# Torsion-free abelian groups are Borel complete

We formalise the Main Theorem of G. Paolini and S. Shelah, *Torsion-free abelian groups are Borel
complete*, Ann. of Math. 199 (3) (2024), 1177–1224, https://doi.org/10.4007/annals.2024.199.3.4
(arXiv:2102.12371).

**Main Theorem.** The space `TFAB_ω` is Borel complete; in fact there is a continuous map
`B : Graph_ω → TFAB_ω` such that for all `H₁, H₂ ∈ Graph_ω`, `H₁ ≅ H₂` if and only if
`B(H₁) ≅ B(H₂)`.

## Conventions

* Structures with domain `ω` in the language `{e, ·, ⁻¹}` of groups are the points of Tau Ceti's
  functional coding space `TauCeti.FunctionalConfiguration Language.group ℕ`: a function table
  giving the value of each function symbol at each tuple in `ℕ`, with the product topology of
  the discrete space `ℕ`. Isomorphism is `TauCeti.FunctionalConfiguration.isoSetoid`, isomorphism
  of the decoded `Language.group`-structures on `ℕ`.
* `TFAB_ω` is `tfabClass` below: the configurations whose decoded identity, inverse and
  multiplication satisfy the axioms of groups (associativity, left identity, left inverse), of
  commutativity, and of torsion-freeness (`xⁿ = e → x = e` for each `n ≥ 1`). The operations are
  read off the configuration as plain functions `ℕ → ℕ`, so that `ℕ`'s own arithmetic plays no
  role.
* `Graph_ω` is Tau Ceti's `TauCeti.RelationalConfiguration.graphClass`: the configurations of
  the language of graphs on `ℕ` whose adjacency relation is symmetric and irreflexive, with the
  product topology. Isomorphism is `TauCeti.RelationalConfiguration.isoSetoid`.
* Borel completeness (the paper's Definition 1.6) is Tau Ceti's
  `TauCeti.FunctionalConfiguration.BorelComplete`: isomorphism on every isomorphism-invariant
  Borel class of structures with domain `ω`, in every countable language, is Borel reducible to
  isomorphism on the class.
* The map `B` is a map between the subspaces `graphClass` and `tfabClass`, continuous for their
  subspace topologies.
-/

open FirstOrder FirstOrder.Language Set

noncomputable section

namespace PaoliniShelah

open TauCeti

namespace Decoded

variable (F : FunctionalConfiguration Language.group ℕ)

/-- The identity `e` decoded from a configuration of the language of groups. -/
def one : ℕ := F.toStructure.funMap TauCeti.Group.oneFunc ![]

/-- The inverse `x⁻¹` decoded from a configuration of the language of groups. -/
def inv (x : ℕ) : ℕ := F.toStructure.funMap TauCeti.Group.invFunc ![x]

/-- The product `x · y` decoded from a configuration of the language of groups. -/
def mul (x y : ℕ) : ℕ := F.toStructure.funMap TauCeti.Group.mulFunc ![x, y]

/-- The power `xⁿ = x · (x · (⋯ (x · e)))` for the decoded operations. -/
def pow (x : ℕ) (n : ℕ) : ℕ := (mul F x)^[n] (one F)

end Decoded

open Decoded in
/-- The class `TFAB_ω` of **torsion-free abelian groups with domain `ω`**: the configurations of
the language of groups on `ℕ` whose decoded operations satisfy the group axioms (associativity,
left identity, left inverse), commutativity, and `xⁿ = e → x = e` for every `n ≥ 1`. -/
def tfabClass : Set (FunctionalConfiguration Language.group ℕ) :=
  {F | (∀ x y z, mul F (mul F x y) z = mul F x (mul F y z)) ∧
    (∀ x, mul F (one F) x = x) ∧
    (∀ x, mul F (inv F x) x = one F) ∧
    (∀ x y, mul F x y = mul F y x) ∧
    ∀ x n, n ≠ 0 → pow F x n = one F → x = one F}

/-- **Paolini–Shelah, Main Theorem.** The class `TFAB_ω` of torsion-free abelian groups with
domain `ω` is Borel complete. In fact there is a continuous map `B` from the codes of countable
graphs on `ℕ` to `TFAB_ω` such that `H₁ ≅ H₂` if and only if `B(H₁) ≅ B(H₂)`. -/
@[eval_problem]
theorem tfab_borelComplete :
    FunctionalConfiguration.BorelComplete tfabClass ∧
      ∃ B : RelationalConfiguration.graphClass → tfabClass, Continuous B ∧
        ∀ H₁ H₂ : RelationalConfiguration.graphClass,
          RelationalConfiguration.isoSetoid Language.graph ℕ H₁ H₂ ↔
            FunctionalConfiguration.isoSetoid Language.group ℕ (B H₁) (B H₂) := by
  sorry

end PaoliniShelah
