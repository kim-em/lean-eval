import Mathlib
import EvalTools.Markers

namespace LeanEval
namespace RepresentationTheory

open scoped TensorProduct

/-!
Existential tensor-square problem for the Mathieu group `M₂₃`.

We assert the existence of a finite group `G` of order `|M₂₃| = 10 200 960`,
together with a `22`-dimensional irreducible complex representation `V`,
such that the tensor square `V ⊗ V` (with the diagonal `G`-action) decomposes
into exactly `4` isotypic components.

Mathematical witness. Take `G = M₂₃` acting on the deleted permutation
representation of its 4-transitive action on 23 points. Let `V` be the
corresponding 22-dimensional irreducible. Then
* `Sym² V` is the permutation representation on the `(23 choose 2) = 253`
  unordered pairs, decomposing as `1 ⊕ V ⊕ W` where `W` is a 230-dimensional
  irreducible.
* `Λ² V` is irreducible of dimension `231` (one of the three 231-dim irreps).

So `V ⊗ V = 1 ⊕ V ⊕ W ⊕ Λ²V` has exactly four pairwise non-isomorphic
irreducible summands.

Mathlib does not yet construct `M₂₃` directly, so any solution must build the
group from scratch (e.g. as a subgroup of `S₂₃` via generators of the Steiner
system `S(4,7,23)`, or from the automorphism group of an extended ternary Golay
code, etc.). The statement does not pin down `M₂₃` uniquely (other groups of
the same order with a 22-dim irrep of the right tensor-square structure would
also satisfy the existential), but while this does not technically require
constructing `M₂₃` and studying its representation theory, we suspect that in
practice it does.

The `MonoidAlgebra ℂ G`-module structures on `V` and `V ⊗[ℂ] V` are bound
explicitly. The `IsScalarTower` constraints anchor them to the underlying
ℂ-module structures, and the explicit diagonal-action equation pins the
`V ⊗ V` action to be `g • (v ⊗ w) = (g • v) ⊗ (g • w)` (extended ℂ-linearly
to the whole group algebra by ℂ-bilinearity of the tensor).
-/

@[eval_problem]
theorem m23_irrep_tensor_square_decomp :
    ∃ (G : Type) (_ : Group G) (_ : Fintype G),
      Fintype.card G = 10200960 ∧
      ∃ (V : Type) (_ : AddCommGroup V) (_ : Module ℂ V)
        (_ : Module (MonoidAlgebra ℂ G) V)
        (_ : IsScalarTower ℂ (MonoidAlgebra ℂ G) V)
        (_ : Module (MonoidAlgebra ℂ G) (V ⊗[ℂ] V))
        (_ : IsScalarTower ℂ (MonoidAlgebra ℂ G) (V ⊗[ℂ] V)),
        Module.finrank ℂ V = 22 ∧
        IsSimpleModule (MonoidAlgebra ℂ G) V ∧
        (∀ (g : G) (v w : V),
          (MonoidAlgebra.of ℂ G g : MonoidAlgebra ℂ G) • (v ⊗ₜ[ℂ] w) =
            ((MonoidAlgebra.of ℂ G g : MonoidAlgebra ℂ G) • v) ⊗ₜ[ℂ]
              ((MonoidAlgebra.of ℂ G g : MonoidAlgebra ℂ G) • w)) ∧
        (isotypicComponents (MonoidAlgebra ℂ G) (V ⊗[ℂ] V)).ncard = 4 := by
  sorry

end RepresentationTheory
end LeanEval
