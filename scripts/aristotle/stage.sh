#!/bin/bash
# Stage an Aristotle-negation workspace for problem $1.
# Copies lean-toolchain and ChallengeDeps.lean (if present), writes a
# minimal lakefile.toml. Does NOT touch Negation.lean — that's hand-written.
set -euo pipefail
pid="$1"
src="generated/$pid"
dst="aristotle-negations/$pid"
[ -d "$src" ] || { echo "no such problem: $pid" >&2; exit 1; }
mkdir -p "$dst"
cp "$src/lean-toolchain" "$dst/lean-toolchain"
extra_libs=""
if [ -f "$src/ChallengeDeps.lean" ]; then
  cp "$src/ChallengeDeps.lean" "$dst/ChallengeDeps.lean"
  extra_libs=$'\n[[lean_lib]]\nname = "ChallengeDeps"'
fi
# Read the Mathlib rev from the source lakefile so we keep the toolchain pin.
rev=$(awk '/^rev = /{gsub(/[" ]/,""); split($0,a,"="); print a[2]}' "$src/lakefile.toml")
cat > "$dst/lakefile.toml" <<TOML
name = "${pid}_negation"

[leanOptions]
autoImplicit = false

[[require]]
name = "mathlib"
git = "https://github.com/leanprover-community/mathlib4.git"
rev = "$rev"
$extra_libs
[[lean_lib]]
name = "Negation"
TOML
echo "staged: $dst"
