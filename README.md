# Lean Eval

**[View the leaderboard →](https://lean-lang.org/eval/)** ·
**[Submit a solution →](https://lean-lang.org/eval/submit/)**

This repository is a comparator-based Lean benchmark for formal mathematics.
Benchmark authors write trusted problem statements once in shared Lean modules, and the
tooling generates one comparator workspace per problem under `generated/`.

A submission is scored entirely by comparator results: a problem counts as solved iff
comparator accepts the submitted solution.

We support the last two stable releases alongside release-candidate and rolling
configurations:

| Configuration | Intended versions |
| --- | --- |
| `stable` | The most recent stable Lean release, with matching Mathlib and TauCeti pins. |
| `previous-stable` | The preceding stable Lean release, with a compatible fixed Mathlib/TauCeti snapshot. |
| `rc` | The most recent supported Lean release candidate newer than stable, with a fixed compatible Mathlib/TauCeti snapshot; otherwise the stable configuration. |
| `latest` (default) | The same Lean toolchain as `rc`, with compatible Mathlib and TauCeti commits that we try to keep fairly current. It may coincide with `rc` and `stable`. |

To request an update, **@Kim Morrison on [Lean Zulip](https://leanprover.zulipchat.com/)**.
Updates require compatible published dependency caches and passing CI, so a new
Lean release can precede our adoption of it. These are four support roles;
`rc` and `latest` share a Lean version and may differ in library revisions.
When a stable release supersedes the supported RC, move `rc` to stable and
advance `latest` to that same snapshot. Keep these names even when configurations
coincide. Retain the preceding stable snapshot as `previous-stable`. Adopt the
next RC for `rc` and `latest` together once compatible libraries and caches pass
validation; retain both stable snapshots meanwhile.
Every configuration pins exact commits, including all transitive dependencies;
evaluation never follows a moving branch.

Maintainers: follow the [configuration update runbook](docs/updating-configurations.md).

The currently available configurations in `supported-toolchains.json` are:

| Configuration | Lean | Mathlib | TauCeti |
| --- | --- | --- | --- |
| `stable` | `v4.36.0` | `fc4f59e5` | `d91980bd` |
| `previous-stable` | `v4.35.0` | `07406378` | `1f9b4414` |
| `rc` | `v4.36.0` | `fc4f59e5` | `d91980bd` |
| `latest` (default) | `v4.36.0` | `fc4f59e5` | `d91980bd` |

`stable`, `rc`, and `latest` currently use the Mathlib and TauCeti `v4.36.0`
release commits; `previous-stable` retains the previously supported 4.35.0 pins.
Lean `v4.37.0-rc1` has been released; `rc` and `latest` remain on stable while
awaiting compatible Mathlib/TauCeti builds for that toolchain.
The superseded `v4.36.0-rc2` snapshot is retired from new evaluations.

The `latest` configuration is the default checkout so it can build the full catalog.
CI requires each problem to compile on every configuration it declares as supported
without unexpected warnings; it does not compare their elaborated meanings
across dependency versions. Cache restoration and sandbox/scoring checks also
run on all four configurations. Mathlib's published cache must cover every module.

Problems may declare one of these support levels in their manifest:

```toml
supported_configurations = ["latest"]
# or ["latest", "rc"]
# or ["latest", "rc", "stable"]
# or ["latest", "rc", "stable", "previous-stable"] (the default when omitted)
```

All problems must support `latest`. Authors can add a problem before it works on
older configurations. Keep statements that need newer APIs in separate Lean
modules from problems that must compile on older configurations; Lean compiles
whole modules, including their imports. CI builds a module on every configuration
needed by any problem in it.

**Upgrades must preserve or increase each existing problem's supported
configurations.** Fix problem sources as necessary for new Lean/Mathlib/TauCeti
versions; do not narrow a problem's support declaration to make an upgrade pass.
CI compares manifests with the base commit and rejects lost compatibility.
Generation and submission evaluation enforce the declared support levels.
New problems may omit `previous-stable` (and other older configurations) by
declaring one of the shorter support lists above. On each stable release,
promote the old `stable` snapshot to `previous-stable` and retire the older one;
keep or repair each problem's declared support on the updated snapshots.

To work on the stable configuration in an isolated directory:

```bash
python scripts/prepare_toolchain.py stable --destination /tmp/lean-eval-stable
cd /tmp/lean-eval-stable
lake exe cache get
cache_env="$(bash scripts/fetch_dependency_caches.sh --restore .)" && eval "$cache_env"
lake exe lean-eval generate --problem two_plus_two
lake exe lean-eval start-problem two_plus_two
```

Use `rc` for the release-candidate snapshot (or its stable fallback), or `latest`
for the default current library snapshot. Existing build outputs are excluded
from these copies.
Use `previous-stable` to prepare the preceding stable release in the same way.
After selecting a configuration, regenerate each
workspace you use so its pins and extracted statements match that configuration.
The submission service reads the closest `lean-toolchain` at or above each
submitted workspace and its exact Mathlib/TauCeti requirements in `lakefile.toml`
to select an approved configuration. The dependency pins distinguish `rc` from
`latest` even when their Lean toolchains are identical. Missing pins use the
default configuration for the requested toolchain; unsupported combinations
are rejected. Identical approved snapshots select the default `latest`
configuration when it matches, so coincident profiles also accept `latest`-only
problems. Submit workspaces for different configurations separately.
Result verification receipts and archive sidecars record the selected toolchain
and exact benchmark commit. The retained source includes the dependency pins,
so replay selects the same configuration from that benchmark commit.

The main user-facing entrypoint is:

```bash
lake exe lean-eval --help
```

## Quick Start For Benchmark Problem Contributors

Use this path if you are adding or editing benchmark problems.

### 1. Install and fetch dependencies

Install Lean through elan and Python 3.11 or newer, then run:

```bash
lake exe cache get
cache_env="$(bash scripts/fetch_dependency_caches.sh --restore .)" && eval "$cache_env"
lake build
```

The second line downloads the oleans of
[Tau Ceti](https://github.com/TauCetiProject/TauCeti), which some problems
import, instead of compiling it, and fails if any would have to be compiled.
This requires lean-eval to pin exactly the Lean toolchain and Mathlib revision
of the pinned Tau Ceti commit, which the script checks.

### 2. Add or edit a trusted theorem

Put the statement in one of the shared modules under `LeanEval/` and mark it with
`@[eval_problem]`.

```lean
@[eval_problem]
theorem my_new_problem : ... := by
  sorry
```

Current source modules live in topic folders such as:

- `LeanEval/NumberTheory/`
- `LeanEval/Topology/`
- `LeanEval/ComplexAnalysis/`
- `LeanEval/EasyProblems.lean`

### 3. Add the manifest entry

Each tagged declaration must be listed by exactly one file under
[`manifests/problems/`](manifests/problems/). One file per problem,
named `<id>.toml`, with top-level keys (no `[[problem]]` wrapper). The
filename stem must match the `id` field. The `holes` array names every
`@[eval_problem]`-tagged declaration in the module that the problem
owns; for the common single-theorem case it has one element.

```toml
# manifests/problems/my_new_problem.toml
id = "my_new_problem"
title = "My new problem"
group = "formalization-evaluation"
status = "draft"
visible = true
statement_revision = 1
tags = []
module = "LeanEval.SomeModule"
holes = ["my_new_problem"]
submitter = "Your Name"
notes = "Optional notes."
source = "Optional citation or URL."
informal_solution = "Optional proof sketch or reference."
```

The required fields are:

- `id` (must equal the filename stem)
- `title`
- `group`
- `status`
- `visible`
- `statement_revision`
- `tags`
- `module`
- `holes`
- `submitter`

The one-file-per-problem layout means two PRs adding distinct problems
never conflict on the manifest.

See [Catalog metadata](docs/catalog-metadata.md) for lifecycle history, the tag
registry, append-only named sets, and the deterministic v1 evidence tool.

The manifest is the only entry point CI has into `LeanEval/`, so a module
no manifest names is never built. `validate-manifest` therefore rejects any
`.lean` file under `LeanEval/` that is neither named by some `module` field
nor imported (directly or transitively) by a module that is, and rejects any
file in `manifests/problems/` that is not a `.toml`.

#### Multi-hole problems

A problem may bundle several `def`s, `instance`s and `theorem`s — list
them all in `holes`. Comparator then asks the participant to fill every
listed declaration in their `Submission.lean`. Two conventions:

- **Name every instance.** The generator addresses holes by their
  declaration name, and Lean's auto-generated names for anonymous
  `instance`s (e.g. `instTopologicalSpaceJacobian`) are not stable. Use
  `instance instAddCommGroup : ... := sorry` rather than `instance : ...
  := sorry`.
- **Use `holes` even for one declaration.** There is no `theorem = "..."`
  shorthand; a singleton hole is just `holes = ["my_thm"]`.

See [`LeanEval/Sandbox/DefHoleExample.lean`](LeanEval/Sandbox/DefHoleExample.lean)
and [`LeanEval/Sandbox/InstanceHoleExample.lean`](LeanEval/Sandbox/InstanceHoleExample.lean)
for the smallest working examples, or
[`LeanEval/Geometry/JacobianChallenge.lean`](LeanEval/Geometry/JacobianChallenge.lean)
for a realistic multi-hole problem.

### 4. Validate the authored source of truth (optional)

```bash
lake exe lean-eval validate-manifest
lake exe lean-eval check-problem-build
```

`validate-manifest` checks that `@[eval_problem]` declarations and manifest entries
match, and that no module under `LeanEval/` escapes the manifest's reach.
`check-problem-build` builds the problem modules so warning-producing Lean changes
do not slip through. Both catch the most common mistakes before a CI roundtrip;
on a clean checkout, validating the full problem inventory can take some time.

### 5. Open a PR

That's it — push your branch and open a PR. CI regenerates the comparator workspaces
under `generated/` and verifies they build, so you do not need to commit anything
under `generated/` yourself. Once the PR merges, a separate workflow regenerates
`generated/` on `main` and pushes the result.

If CI fails with a generation or build error, you'll need to fix the source. The
fastest local equivalent is:

```bash
lake exe lean-eval generate --problem my_new_problem
lake exe lean-eval check-generated-builds --problem my_new_problem
```

## Quick Start For Solvers

Use this path if you want to prove benchmark problems without touching the trusted
benchmark files.

### 1. Pick a problem

Generated workspaces live under `generated/`, one directory per problem. The current
catalog is summarized in [`generated/index.json`](generated/index.json).

Examples:

- `generated/two_plus_two/`
- `generated/list_append_singleton_length/`
- `generated/cyclotomic_integer_house_le_two/`

### 2. Create your local workspace

Copy a clean starter workspace:

```bash
lake exe lean-eval start-problem two_plus_two
```

That creates `workspaces/two_plus_two/` by default. You can also pass a destination:

```bash
lake exe lean-eval start-problem two_plus_two /tmp/two_plus_two
```

### 3. Install workspace dependencies

```bash
cd workspaces/two_plus_two
lake update
```

### 4. Write your proof

Solver-owned files are:

- `Submission.lean`
- `Submission/Helpers.lean`
- any additional Lean files you add under `Submission/`

Trusted files you should not edit in the normal solver workflow are:

- `Challenge.lean`
- `Solution.lean`
- `config.json`
- `lakefile.toml`

`Challenge.lean` contains the benchmark statement. `Solution.lean` is the fixed bridge
that tells comparator to check your theorem from the `Submission` namespace.

Solutions may import modules from [Lean Pool](https://github.com/Vilin97/lean-pool),
[CFSG](https://github.com/AxiomMath/CFSG), and
[Stacks](https://github.com/AxiomMath/Stacks) in `Submission.lean` or `Submission/`
helpers. These pinned dependencies are included in generated workspaces via
`solution-dependencies.json`. Problem statements and their local helpers may not
import them; workspace generation rejects these imports. Comparator and NanoDa
checks apply as usual.

After fetching the workspace dependencies, prepare the libraries it imports:

```bash
cache_env="$(bash /path/to/lean-eval/scripts/fetch_dependency_caches.sh --restore .)" && eval "$cache_env"
```

This parses Lean import headers, fetches each required library's revision mappings,
and restores only the imported modules and their transitive dependencies. It uses
`lake --no-build`, so missing artifacts fail rather than starting a large rebuild.
Each library must match the workspace's Lean toolchain and all transitive dependency
pins. Unused libraries require no artifact downloads.

The public CFSG pin still uses v4.35.0-rc3. Stacks uses v4.35.0 with Mathlib
`56a00585`, while LeanEval's stable configuration uses Mathlib `fc4f59e5` to
match its pinned TauCeti commit. These library imports fail the cache compatibility
check until matching dependency builds are published, including the Mathlib pin.
Unused solution libraries do not prevent evaluation on any supported configuration. The helper
uses the published [CFSG cache](https://cfsg-downloads.axiommath.workers.dev/lake/lake-cache-get-fast.sh)
and [Stacks cache](https://stacks-cache.axiommath.workers.dev/lake/lake-cache-get-fast.sh)
endpoints by default. Set `STACKS_ARTIFACT_ENDPOINT` and `STACKS_REVISION_ENDPOINT`
to override the Stacks endpoints; corresponding overrides are available as
`CFSG_*` and `TAUCETI_*`. CI and the submission runner accept the Stacks overrides
from repository variables with those same names; empty variables use the defaults.

### 5. Run comparator locally

```bash
lake test
```

The pinned Lean toolchain includes Lake comparator, `leanexport`, the Lean
checker, and NanoDa. The trusted test driver always requires both Lean and NanoDa.
The only additional verifier dependency is bubblewrap on Linux with user namespaces.

Install bubblewrap 0.12.0 using the same checksum-verified installer as CI
(requires Meson, Ninja, libcap development headers, curl, and a C compiler):

```bash
# Run from the lean-eval repository root, outside a problem workspace.
export COMPARATOR_BWRAP="$(bash scripts/install_bwrap.sh "$PWD/.tools/bubblewrap")"
```

On Ubuntu 24.04 the installer loads an executable-specific AppArmor profile using
`sudo` when user namespaces are restricted. On a system where bubblewrap 0.12.0
is already configured, put `bwrap` on PATH or set `COMPARATOR_BWRAP` to its
absolute path.

Check the installation against the starter problem:

```bash
lake exe lean-eval check-comparator-installation
```

Run `lake test` in a problem workspace to invoke the toolchain's
`lake comparator`. It pins the exporter and checker to the same Lean release,
avoiding separate exporter builds and incompatible olean formats. When changing
toolchains, refresh the dependency caches and remove stale workspace build outputs.

The trusted driver uses Lake's `LAKE` and `LEAN_SYSROOT` settings and removes
workspace/cache directories from executable and library search paths before
starting comparator. `LEAN_PATH` remains available for module imports.
Install bubblewrap and the toolchain outside submission-writable directories.
The old `COMPARATOR_BIN`, `COMPARATOR_LANDRUN`, `COMPARATOR_LEAN4EXPORT`,
and `COMPARATOR_NANODA` overrides are no longer used.

Root scoring makes the trusted shared package cache visible read-only inside
Lake's sandboxes. Direct local workspaces can keep their own dependencies; no
cache wrapper is needed for that layout.

### 6. Check your local score

From the repo root:

```bash
lake exe lean-eval run-eval
lake exe lean-eval run-eval --json
```

The scorer prefers `workspaces/<problem-id>/` when present and falls back to
`generated/<problem-id>/` otherwise.

## Submission Rules

For current instructions to **submit a solution**, start at the stable page:

> **[lean-lang.org/eval/submit/](https://lean-lang.org/eval/submit/)**

That page is the primary authenticated submission path from
`2026-09-02T06:57:10Z`. The application itself is at
`https://lean-eval-submission-server.lean-eval.workers.dev/`; this change of
origin is expected.

[Submission issue
intake](https://github.com/leanprover/lean-eval-submissions/issues/new?template=submit.yml)
remains available as a fallback through at least `2026-09-30T06:57:10Z`, four
weeks after the overlap began. Conditional on stable operation, adequate
adoption, no unresolved severity-high incident, and a reconciled final corpus,
that is the planned retirement time. This notice was issued at
`2026-09-02T23:06:35Z`, more than two weeks in advance. Retirement will be
postponed if any gate is not satisfied.

Scheduled release is recommended for authenticated intake, while submitters
may keep accepted source private instead. Once selected, scheduled release
cannot be changed back to private. Accepted source is published under the
Apache License 2.0 exactly two UTC calendar months after acceptance. A
submitter who initially chooses private source may later change that choice
once to scheduled release.

The service takes a problem ID and resolves its group and current statement
revision from the protected LeanEval catalog; clients do not supply those
canonical fields. Formalization problems must be visible and active.
Software-verification problems may be visible and draft or active. Public
source repositories must use scheduled publication; withholding is available
only for private repositories.

Before acceptance, the submitter explicitly authorizes private fetch, archive,
build, and execution of the exact commit, indefinite encrypted retention even
after rejection or failure, and public display of the result and submitted
metadata. Do not submit secrets. Every new request is archived with a fresh
per-submission key envelope before evaluation, and the service evaluates only
the selected problem. Exact resubmissions by the same owner return the original
submission, and each owner may have at most four active submissions.

This repository (`leanprover/lean-eval`) holds only the problem set and the
comparator/sandbox integration.

Participants may use Mathlib freely.

If a proof needs helper code that is not already in Mathlib, that code must be included
inside the submission workspace itself. Multi-file submissions are allowed through
`Submission.lean` and extra local modules under `Submission/`.

For benchmark-repo submissions (a PR that edits a `generated/` workspace in place),
validate changed paths with:

```bash
lake exe lean-eval validate-submission --file generated/two_plus_two/Solution.lean
```

The current validator accepts:

- modifications to `generated/<problem-id>/Solution.lean` and
  `generated/<problem-id>/Submission.lean`
- additions, modifications, deletions, renames, or copies of `.lean` files under
  `generated/<problem-id>/Submission/`
- additions (only) of markdown files anywhere inside
  `generated/<problem-id>/`, other than the generated `README.md`
- additions (only) of a top-level `generated/<problem-id>/LICENCE` or
  `generated/<problem-id>/LICENSE` file

In practice, solvers should normally work in `Submission.lean` and `Submission/`.

## Repository Layout

- [`LeanEval/`](LeanEval): trusted authored problem statements
- [`manifests/problems/`](manifests/problems/): one TOML file per problem, named `<id>.toml`
- [`manifests/tags.toml`](manifests/tags.toml): stable tag registry
- [`manifests/sets/`](manifests/sets/): versioned and optionally frozen named problem sets
- [`generated/`](generated): generated comparator workspaces
- [`scripts/`](scripts): generation, validation, and scoring helpers
- [`PLAN.md`](PLAN.md): deferred design and roadmap notes

## End-To-End Repo Checks

`bash scripts/fetch_dependency_caches.sh --restore .` restores imported TauCeti,
CFSG, and Stacks modules without permitting compilation. Downloads have bounded retries and
timeouts and use temporary files to keep interrupted transfers out of the
artifact cache. Cache-only restoration is retried once; if it still fails, the
script prints verbose diagnostics before stopping. Verify the pinned versions
and published cache when outputs are missing. The exported cache settings keep
the download wrapper active for subsequent trusted builds.

For a local health pass over the repository:

```bash
lake exe lean-eval validate-manifest
lake exe lean-eval check-problem-build
lake exe lean-eval generate --check
lake exe lean-eval check-generated-builds
lake exe lean-eval run-eval
```

There is also an end-to-end workflow self-check:

```bash
lake exe lean-eval check-eval-workflow
```
