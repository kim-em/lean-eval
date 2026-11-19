# Updating supported configurations

Use this runbook to refresh `latest`, adopt a new RC, or adopt a new stable
release. The [README policy](../README.md) defines the three profiles and the
allowed per-problem support levels. Ask **@Kim Morrison on
[Lean Zulip](https://leanprover.zulipchat.com/)** for an update.

## 1. Select a compatible, published snapshot

Start an update branch from upstream `main`. Record its base commit for the
compatibility check below. Check the current Lean releases and TauCeti release
tags, then choose an exact TauCeti commit:

```bash
git fetch origin main
base_ref=$(git rev-parse origin/main)
gh release list --repo leanprover/lean4 --limit 6
gh api 'repos/TauCetiProject/TauCeti/tags?per_page=10' --jq '.[].name'
```

For `stable`, choose the newest stable Lean release and compatible libraries.
For `rc`, choose the newest Lean RC and a compatible fixed library snapshot.
For `latest`, choose a recent TauCeti commit on that same RC, using exactly its
Mathlib revision and transitive dependency pins. A recent Mathlib commit alone
is insufficient: TauCeti's artifacts must match the complete dependency set.

Use stock Lean releases. A commit on TauCeti `main` may not yet have a published
cache; select a recent cached ancestor if necessary. If matching libraries or
caches for a new Lean release are not ready, keep the working configuration and
record the adoption gap in the README. Do not advertise that release as supported
until the checks below pass. When the RC changes, update both `rc` and `latest`
to that RC in the same update.

Inspect the candidate's metadata without checking out its entire source tree:

```bash
tau_rev=REPLACE_WITH_EXACT_40_CHARACTER_COMMIT
tau_checkout=$(mktemp -d)
git -C "$tau_checkout" init -q
git -C "$tau_checkout" remote add origin https://github.com/TauCetiProject/TauCeti
git -C "$tau_checkout" sparse-checkout set --no-cone /lean-toolchain /lake-manifest.json
git -C "$tau_checkout" fetch --filter=blob:none --depth=1 origin "$tau_rev"
git -C "$tau_checkout" checkout -q --detach FETCH_HEAD
cat "$tau_checkout/lean-toolchain"
python - "$tau_checkout/lake-manifest.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
print(next(p["rev"] for p in data["packages"] if p["name"] == "mathlib"))
PY
```

## 2. Update all three pin files together

Choose the destination profile directory. `latest` always uses
`toolchains/latest`. For a new stable or RC toolchain, copy its previous profile
to `toolchains/<new-version>` first; retain independent solution-library and
generator pins unless those dependencies also need an update.

The following recipe updates the selected profile from the candidate checkout:

```bash
profile=toolchains/latest
python - "$profile" "$tau_checkout" <<'PY'
import json, pathlib, subprocess, sys, tomllib
profile, checkout = map(pathlib.Path, sys.argv[1:])
tau_rev = subprocess.check_output(
    ["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
subprocess.run(["git", "-C", str(checkout), "diff", "--exit-code", "HEAD", "--",
                "lean-toolchain", "lake-manifest.json"], check=True)
snapshot = json.loads((checkout / "lake-manifest.json").read_text())
shared = {p["name"].strip("«»"): p for p in snapshot["packages"]}
lakefile = (profile / "lakefile.toml").read_text()
requirements = tomllib.loads(lakefile)["require"]
for dependency in requirements:
    name = dependency["name"]
    if name in shared and name != "mathlib" and dependency["rev"] != shared[name]["rev"]:
        raise ValueError(f"Independent dependency {name} also needs a compatible pin")
    if name in {"TauCeti", "mathlib"}:
        revision = tau_rev if name == "TauCeti" else shared["mathlib"]["rev"]
        lakefile = lakefile.replace(f'rev = "{dependency["rev"]}"', f'rev = "{revision}"')
manifest = json.loads((profile / "lake-manifest.json").read_text())
packages = {p["name"].strip("«»"): p for p in manifest["packages"]}
packages["TauCeti"].update(rev=tau_rev, inputRev=tau_rev)
packages["mathlib"].update(rev=shared["mathlib"]["rev"], inputRev=shared["mathlib"]["rev"])
for name, dependency in shared.items():
    if name != "mathlib":
        packages[name] = dependency
manifest["packages"] = list(packages.values())
(profile / "lean-toolchain").write_bytes((checkout / "lean-toolchain").read_bytes())
(profile / "lakefile.toml").write_text(lakefile)
(profile / "lake-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY
```

For a stable or RC version change, update `supported-toolchains.json`:

- Register the new exact `leanprover/lean4:v...` key and profile directory.
- Point `stable` or `rc` at that key, removing its old configuration entry.
- Keep `latest` and `default` pointing at `latest`.
- Remove retired profile directories once no registry entry refers to them.

Existing archived evaluations retain their original benchmark commit, so their
configuration remains available there. Update actual-version assertions in
`tests/python/test_prepare_toolchain.py` when changing supported Lean versions;
the synthetic historical versions in selector fixtures need not change.

Synchronize the root checkout with its default profile, and update the README's
actual-support table and any release-adoption note:

```bash
python - <<'PY'
import json, pathlib, shutil
root = pathlib.Path.cwd()
registry = json.loads((root / "supported-toolchains.json").read_text())
profile = root / registry["configurations"][registry["default"]]
for name in ("lean-toolchain", "lakefile.toml", "lake-manifest.json"):
    shutil.copyfile(profile / name, root / name)
PY
```

Use a fresh validation checkout rather than reusing `.lake` across profiles.
Do not use `lake update` to choose arbitrary newer shared dependencies after
copying the compatible snapshot.

## 3. Preserve problem compatibility

Run from the update branch's root:

```bash
python scripts/problem_configurations.py --base "$base_ref"
python scripts/validate_catalog.py --base-ref "$base_ref"
python -m unittest discover -s tests/python -p 'test_*.py'
python scripts/action_pin_audit.py
```

Existing problems retain their declared support sets; omission means all three
profiles. New problems may start at `latest` or `latest` plus `rc`. If an upgrade
breaks an existing problem, repair its statement source, imports, or API usage
instead of reducing its support. Keep any required statement-revision and
lifecycle metadata consistent with the catalog's existing rules.

Keep incompatible declarations in separate source modules: a module must compile
on every profile needed by any problem in it. The compatibility check rejects
narrowed declarations, while compilation checks actual compatibility.

## 4. Validate each profile and its caches

Repeat this sequence for `latest`, `rc`, and `stable`:

```bash
configuration=latest
validation_root=$(mktemp -d)
python scripts/prepare_toolchain.py "$configuration" --destination "$validation_root/$configuration"
cd "$validation_root/$configuration"
python scripts/prepare_ci_dependencies.py
lake exe cache get
lake --no-build build Mathlib
cache_env="$(bash scripts/fetch_dependency_caches.sh --restore .)" && eval "$cache_env"
lake exe lean-eval check-problem-build
lake exe lean-eval validate-manifest --assume-modules-built
lake exe lean-eval generate
```

`prepare_ci_dependencies.py` materializes metadata for solution-only packages,
keeping catalog validation small. The submission runner still uses full source
checkouts. Missing dependency caches must fail rather than trigger dependency
compilation. Mathlib's complete cache and imported TauCeti artifacts must restore
for the exact selected Lean and dependency pins.
Keep the helper's exported `LAKE_RESTORE_ARTIFACTS=true`: runtime extraction and
inventory tools need canonical `.olean` paths even when builds reuse a warm
artifact cache from another checkout or profile.

Run Lean unit tests and representative generated workspace builds, including
problems changed during the upgrade and one importing TauCeti. CI also requires
cache restoration and comparator sandbox/scoring checks on all three profiles.
Unexpected warnings must be fixed; benchmark placeholder `sorry` warnings are
the existing exception.

```bash
lake exe test_generate
lake exe test_module_coverage
lake exe test_validate_submission
lake exe test_check_comparator_installation
```

Return to the update branch before preparing the next profile. Generated files
from validation copies are disposable: committed default workspaces are updated
by the trusted main-branch regenerator.

## 5. Review, merge, and verify rollout

Open the PR against upstream `main`, naming the exact Lean, Mathlib, and TauCeti
pins and any upstream prerequisites. For a dependent PR, keep `main` as its target
and add a comment naming the prerequisite PRs. Require both `verify` and `restore` to pass.
Use one conservative monitor per run rather than polling checks repeatedly:

```bash
gh run watch RUN_ID --repo leanprover/lean-eval --exit-status --interval 120
```

After a monitor exits, use `gh run view` or the run's jobs API for exact job states
and failure logs. Fix failures before merging. If prerequisite PRs must merge
first, wait for them before adopting their final commits and caches.

After merge, confirm the main-branch regeneration workflow passes and its
generated workspaces use the default pins. Confirm a new archived evaluation
records the expected benchmark commit and Lean toolchain, with source dependency
pins selecting the intended profile. Replay must continue to use the retained
source and exact historical benchmark commit; do not rewrite archived pins.
