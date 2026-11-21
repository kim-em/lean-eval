# Updating supported configurations

Use this runbook to refresh `latest`, adopt a new RC, or adopt a new stable
release. The [README policy](../README.md) defines the four profiles and the
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
For `previous-stable`, retain the preceding stable release's working snapshot.
When adopting a new stable release, move the old `stable` configuration to
`previous-stable` before replacing `stable`; retire the former `previous-stable`
only after no registry alias needs it. For example, adopting 4.37.0 will move
4.36.0 to `previous-stable` and retire 4.35.0. This is a rolling two-release
support window, not a promise to evaluate new submissions on every past release.

For `rc`, choose the newest Lean RC newer than stable and a compatible fixed
library snapshot. If no such RC is supported yet, point `rc` at stable.
For `latest`, choose a recent TauCeti commit on the same Lean toolchain as `rc`,
using exactly its Mathlib revision and transitive dependency pins. A recent
Mathlib commit alone is insufficient: TauCeti's artifacts must match the complete
dependency set.

Some solution libraries publish a different compatible Mathlib snapshot on the
same Lean release. Register these as library variants, preserving the canonical
four support roles. For example, `stacks` uses the published Lean 4.35.0/Mathlib
release cache, while canonical `previous-stable` uses TauCeti's later Mathlib pin.
The registry's `variants` entry assigns a `support_role` and lists any
`unsupported_modules` requiring unavailable library artifacts.
Retain all configured solution-library requires: the workspace generator validates
them even when unused. A variant must use the same
Lean toolchain as that role. Validate all remaining modules and real solver
imports with compilation disabled for dependency restoration.

CFSG currently needs no variant: its published Lean 4.35.0 build matches
canonical `previous-stable`'s Mathlib and TauCeti pins. Update that profile's
CFSG require and manifest entry together, including `configFile` if upstream
moves between `lakefile.lean` and `lakefile.toml`. Keep the working core pins;
a matching Lean version alone is insufficient. CI restores a CFSG module with
compilation disabled and scores a CFSG-importing submission through both kernels.

The four names describe support roles, not necessarily four distinct versions.
When adopting a stable release that supersedes the current RC, retire that RC,
point `rc` at stable, and advance `latest` to the new stable snapshot in the same
update. For example, after adopting `v4.36.0`, `stable`, `rc`, and `latest` may use
identical `v4.36.0` Lean/Mathlib/TauCeti pins until `v4.37.0-rc1` is ready for us,
while `previous-stable` remains on `v4.35.0`. Do not keep
`v4.36.0-rc2` just to fill the RC slot, or leave `latest` behind stable.

This fallback also covers the interval after the next Lean RC is tagged but
before compatible Mathlib/TauCeti commits and published caches are available.
Once that RC passes the validation below, move both `rc` and `latest` to it;
leave both stable configurations on their stable releases. `latest` can initially
use the RC snapshot and then advance to newer compatible library commits. If a supported RC already
uses a newer Lean release than the new stable, retain that newer RC and `latest`.

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
- For a new stable release, first point `previous-stable` at the old `stable` key.
- Point `stable` or `rc` at the new key. They may both point at the same key.
- Remove old configuration entries only when no alias refers to them.
- Keep `latest` and `default` pointing at `latest`.
- Remove retired profile directories once no registry entry refers to them.

Existing archived evaluations retain their original benchmark commit, so their
configuration remains available there. Update actual-version assertions in
`tests/python/test_prepare_toolchain.py` when changing supported Lean versions;
the synthetic historical versions in selector fixtures need not change.
Update the stable-version paths in the pipeline toolchain contract step of
`.github/workflows/ci.yml` as part of each stable promotion.

For the interval between a stable release and adoption of the next RC, reuse
the stable profile for `rc` and copy its exact three pin files into `latest`:

```bash
python - <<'PY'
import json, pathlib, shutil
root = pathlib.Path.cwd()
path = root / "supported-toolchains.json"
registry = json.loads(path.read_text())
registry["rc"] = registry["stable"]
retained = {registry[alias] for alias in ("default", "stable", "previous-stable", "rc", "latest")}
retained.update(registry.get("variants", {}))
for key in list(registry["configurations"]):
    if key not in retained:
        del registry["configurations"][key]
path.write_text(json.dumps(registry, indent=2) + "\n")
stable = root / registry["configurations"][registry["stable"]]
latest = root / registry["configurations"][registry["latest"]]
for name in ("lean-toolchain", "lakefile.toml", "lake-manifest.json"):
    shutil.copyfile(stable / name, latest / name)
PY
```

Remove the retired RC directory after checking that no registry entry uses it.
Keep `toolchains/latest` so future library updates can advance it independently.
No selector special case is needed: matching identical snapshots prefer the
default `latest`, including for problems declared `latest`-only. Keep all existing
problem support declarations; coincident profiles must not lose support when
they split again on adoption of the next RC.
On stable promotion, update variants to their role's new Lean toolchain or
retire those tied to the release leaving the support window. Archived evaluations
retain the original variant through their benchmark commit. For a retained
variant, the compatibility check rejects decreased problem coverage.

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

Existing problems retain their declared support sets; omission means all four
profiles. New problems may start at `latest`, `latest` plus `rc`, or `latest`
plus `rc` and `stable`; only the full list includes `previous-stable`. If an upgrade
breaks an existing problem, repair its statement source, imports, or API usage
instead of reducing its support. Keep any required statement-revision and
lifecycle metadata consistent with the catalog's existing rules.

Do not put library-variant names in `supported_configurations`: they inherit the
assigned role's declaration and apply their registry module restrictions. A new
problem that omits `previous-stable` also declines `stacks`. Restrictions on a
library variant do not narrow support on its canonical role.

Keep incompatible declarations in separate source modules: a module must compile
on every profile needed by any problem in it. The compatibility check rejects
narrowed declarations, while compilation checks actual compatibility.

## 4. Validate each profile and its caches

Repeat this sequence for `latest`, `rc`, `stable`, `previous-stable`, and registered
variants, currently `stacks`. Restore libraries only for eligible problem modules
and submitted imports; a whole-root import scan includes excluded modules too.

```bash
configuration=latest
validation_root=$(mktemp -d)
python scripts/prepare_toolchain.py "$configuration" --destination "$validation_root/$configuration"
cd "$validation_root/$configuration"
python scripts/prepare_ci_dependencies.py
lake exe cache get
lake --no-build build Mathlib
if [ "$configuration" != stacks ]; then
  cache_env="$(bash scripts/fetch_dependency_caches.sh --restore .)" && eval "$cache_env"
fi
lake exe lean-eval check-problem-build
lake exe lean-eval validate-manifest --assume-modules-built
lake exe lean-eval generate
```

`prepare_ci_dependencies.py` materializes metadata for solution-only packages,
keeping catalog validation small. The submission runner still uses full source
checkouts. Missing dependency caches must fail rather than trigger dependency
compilation. Mathlib's complete cache and imported TauCeti artifacts must restore
for the exact selected Lean and dependency pins.
The restore helper gives the stock archive extractor up to 64 MiB of stack
(within the host's hard limit). Lean 4.37.0-rc1 needs this for deeply nested
TauCeti proofs; calling `lake --no-build` directly with the usual 8 MiB stack
can crash during extraction even when the archive is valid.
Keep the helper's exported `LAKE_RESTORE_ARTIFACTS=true`: runtime extraction and
inventory tools need canonical `.olean` paths even when builds reuse a warm
artifact cache from another checkout or profile.

Run Lean unit tests and representative generated workspace builds, including
problems changed during the upgrade and one importing TauCeti. CI also requires
cache restoration and comparator sandbox/scoring checks on all four profiles.
The Stacks variant additionally restores an actual Stacks import from the public
cache and runs comparator/scoring smoke tests with that import in the submission.
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

When default pins or statement sources change, confirm the main-branch
regeneration workflow passes and its generated workspaces use the default pins.
The main-advance notification then triggers the leaderboard's benchmark-snapshot
update and site deployment; confirm the snapshot records the new benchmark
commit and default pins, and verify the live site.

An update confined to a nondefault profile, such as the CFSG pin in
`previous-stable`, leaves the default workspaces and site snapshot unchanged;
the path-filtered regeneration and notification workflows do not run for it.
Verify the selected profile and real source-archive selection against the merged
benchmark commit, including the cache-only restoration and scoring checks above.
The submissions pipeline reads these benchmark-owned profiles directly; this
pin update does not require a Worker deployment.

Confirm source archive selection records the expected Lean toolchain and resolves
the exact dependency pins to the intended profile. When checking a new real
evaluation, its archive must also record the expected benchmark commit. Replay
must continue to use the retained source and exact historical benchmark commit;
do not rewrite archived pins.
