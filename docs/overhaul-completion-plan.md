# LeanEval lifecycle overhaul completion plan

Status: **accepted scope for completing the overhaul**  
Adopted: 2026-08-25  
Production posture at adoption: intake, general replay, production replay, and
automatic publication are disabled.

## 1. Authority and use

This document is the scope authority for all remaining lifecycle-overhaul work.
It is a maintainer amendment to [`PLAN.md`](../PLAN.md), not a new product RFC.
It narrows the original program after implementation experience exposed work
that was disproportionate or outside LeanEval's boundaries.

The companion [`overhaul-execution-runbook.md`](overhaul-execution-runbook.md)
turns this scope into ordered gates and a mutable completion checklist. When
the two documents differ:

1. this completion plan decides **what** is in scope and what counts as done;
2. the runbook decides the current order and status of that work;
3. tracked runtime configuration and current infrastructure inventories decide
   the observed operational state, but cannot expand scope.

The original plan remains authoritative for retained product details such as
problem lifecycle, structured metadata, immutable snapshots, two-calendar-
month release policy, append-only State, leaderboard behavior, and replay
measurements. The explicit amendments in this document take precedence over
conflicting original text.

## 2. Two completion milestones

The overhaul has two deliberately separate milestones.

### 2.1 Production launch

Production launch means that a new submission can:

1. enter through the new server;
2. receive a per-submission encrypted archive before evaluation;
3. be evaluated from its immutable snapshot;
4. produce an immutable accepted or rejected result and append-only lifecycle
   state;
5. appear correctly on the lifecycle-aware leaderboard;
6. be scheduled for automatic release under the two-calendar-month policy;
7. use the launch-approved owner and maintainer lifecycle functions; and
8. be paused or rolled back through a tested disable path.

Historical-corpus replay is not a production-launch blocker. The old issue
intake also remains open during the overlap.

### 2.2 Full overhaul completion

The whole overhaul is complete only after production launch **and**:

- every legacy accepted result recorded before issue intake closes has either
  a terminal official-kernel-plus-nanoda replay record or a reviewed
  unavailable reason;
- every recoverable historical private archive in that scope has the required
  per-submission envelope for replay;
- the neutral open-problems tab exists (it may be empty initially);
- the retained software-verification and editorial work is in its agreed
  state; and
- the four-week issue-intake overlap has completed and issue intake has been
  retired under the incident and notice gates below.

This distinction allows the useful new system to launch without pretending
that the historical migration is finished.

Production launch is the immediate operating milestone. Once the launch gates
in section 7 are satisfied, proceed directly through the ordered production
steps in section 8. Do not delay launch for a fresh exact-candidate live matrix
of optional lifecycle routes, historical completion, the issue-intake overlap,
or the production canary's later release date. Full overhaul completion remains
calendar-bound by the overlap and notice periods and by verification of the
production canary's first automatic release at its two-calendar-month due time.

## 3. Retained product scope

The following remain part of the overhaul.

### 3.1 Problems and leaderboard

- Lifecycle metadata, immutable statement revisions, status history, tags,
  visibility, and frozen-set membership.
- The frozen 128-member formalization-evaluation v1 set.
- Lifecycle-aware group and problem pages with stable URLs and visible problem
  statements.
- Client-rendered data-heavy pages, unique-solve and total-solve standings,
  recent solutions, metadata provenance, replay statistics, and released-
  solution links.
- The software-verification group and its already reviewed draft problems.
- A neutrally named **open problems** tab. It has no FC dependency and may
  launch empty.

### 3.2 Submission lifecycle

- Browser OAuth and the source-bound headless-agent path.
- Structured, self-reported model, human-involvement, prompt, compute, and
  provenance metadata.
- Immutable source snapshots archived before evaluation.
- Append-only State transitions and immutable base Results records.
- Metadata backfill, result repair and retraction requests, maintainer
  decisions, model aliases, and model renaming.
- A visible initial choice between scheduled publication and private source,
  one-way later private-to-scheduled opt-in, and the automatic
  two-calendar-month release policy. Scheduled publication cannot later be
  changed to private. Do not expose a separate publication opt-out in forms,
  APIs, or submitter-facing documentation; that reverse path remains disabled.
- An operator-controlled emergency pause and deterministic recovery path.

### 3.3 Archive and release

- A provider-neutral schema-version-3 sidecar with one fresh key envelope per
  submission, strict submission/digest binding, and separated wrap/unwrap
  authority.
- Automatic reconstruction and publication from the accepted immutable
  snapshot, with source and credentials excluded from public logs and
  artifacts.
- Existing grandfathering policy for legacy submissions, without inferring a
  new publication choice for them.

### 3.4 Historical replay and statistics

- Historical migration covers every legacy accepted Result recorded before
  issue intake closes. The already completed frozen v1 corpus remains an
  immutable baseline; drain the preserved non-v1 public and private queues,
  then freeze and drain the final append-only issue-intake delta at cutoff.
- Exact original source, benchmark, toolchain, and component pins.
- The ordinary Lean build/elaboration path (the official kernel) and nanoda.
- Terminal distinctions between acceptance, checker rejection, orchestration
  failure, timeout, resource limit, and unavailability.
- Versioned checker identity/revision and measurement-series fields, so a
  later project can replay old submissions with other kernels without another
  archive migration.
- Build cost, checker cost, size, and other already specified measurements when
  the pinned runtime can collect them.

## 4. Explicit scope reductions

The following are not requirements for launch or full overhaul completion.
They must not be revived merely because old planning text, a branch, or an
unchecked tracker item mentions them.

### 4.1 Formal Conjectures and disproofs

- No Formal Conjectures importer, FC100 integration, synchronization, external
  coordination, or FC-owned content lane.
- No comparator disproof support.
- No dependency on any Formal Conjectures pull request.
- The open-problems tab remains provider-neutral and may be empty.

### 4.2 Experimental kernels

- No Lean Kernel Arena candidate work.
- No Mathgraph or other experimental checker integration.
- No checker-series, corpus-promotion report, source-free runner-attestation
  protocol, candidate promotion decision, or checker-author workflow.
- No persistent qualification system for future kernels.

The only obligation is not to make the replay and archive formats inherently
nanoda-only forever. A versioned schema extension point is sufficient.

### 4.3 Disproportionate qualification machinery

- Delete the persistent model-identity qualification harness, its private
  Workers, Durable Objects, workflows, fixtures, generated types, recovery
  protocol, and rebuild instructions.
- Do not replace it with another persistent qualification service.
- Do not require exhaustive failure injection, contention matrices, recurring
  certification runs, or a dedicated qualification control plane for launch.

Existing focused unit tests and ordinary security hardening remain valuable;
scope reduction is not permission to regress source-bound sessions,
authorization checks, State CAS/idempotency, or fail-closed behavior.

### 4.4 Other deferrals

- Automated copycat detection remains deferred.
- Provider-loss recovery and a second key provider remain out of scope.
- Verified-calculation performance infrastructure requires a later trusted-
  runner specification.
- Agent-authored hints and flavour text remain prohibited; editorial text is
  human work.
- Model consolidation need not be enabled for launch or completion. Preserve
  the existing implementation only if it is inexpensive and safe to keep dark;
  otherwise remove it and revisit consolidation separately.
- No new exhaustive infrastructure linter, drift service, or recurring
  qualification harness without a new maintainer decision.

## 5. Submission entry point and OAuth

No dedicated LeanEval hostname is required.

- Publish a stable static entry page at
  `https://lean-lang.org/eval/submit/` in the existing leaderboard site.
- The entry page sends the user to the authenticated production application on
  `lean-eval-submission-server.lean-eval.workers.dev`.
- Keep OAuth callbacks and session cookies on that Worker origin. The browser
  address may change to `workers.dev` while the form is open.
- Do not involve the `lean-lang.org` DNS or Cloudflare-zone owners merely to
  keep the form under the vanity path.

Serving the interactive application literally at `/eval/submit/` would require
a same-origin dynamic route or proxy on the `lean-lang.org` zone and is outside
the launch plan.

Temporary private ownership of the production OAuth application is acceptable
for initial launch. Record the owner, credential custodian, recovery method,
rotation method, and intended organization-transfer path, but organization
ownership is not a launch gate.

## 6. Launch lifecycle functionality

Launch with most of the implemented lifecycle surface available.

| Function | Launch disposition | Minimum launch evidence |
| --- | --- | --- |
| New browser submission | Enable | Exact launch-candidate private submission through archive, evaluation, immutable Result, and append-only State |
| Headless-agent submission | Enable | Exact launch-candidate source-bound submission through archive, evaluation, immutable Result, and append-only State |
| Metadata backfill | Enable | Repository tests and the retained prior bounded staging owner-success/non-owner-denial evidence |
| Repair and retraction requests | Enable | Repository tests and the retained prior bounded staging valid/invalid or non-owner evidence |
| Maintainer decisions | Enable | Repository tests and the retained prior bounded staging maintainer/non-maintainer evidence |
| Model alias and rename | Enable | Repository tests and the retained prior bounded staging success/collision or non-owner evidence |
| Publication opt-in | Enable | Packet-bound production canary, initially private, then irreversibly opted in with its atomic release schedule and presentation checked |
| Model consolidation | Keep disabled or remove | Not a launch test |

Publication opt-out is not part of the launch surface. Keep its implementation
gate disabled and omit it from user-facing forms and documentation.

The exact-candidate live prelaunch smoke is deliberately limited to the browser
and headless archive-evaluate-Result paths. Existing repository tests and prior
bounded staging route evidence are sufficient for the optional lifecycle route
families; do not rerun them as an exact-candidate live matrix. Publication
opt-in is proved once on the production canary, not by another staging
submission. This remains a bounded acceptance exercise, not a qualification
campaign: launch does not require a persistent harness, repeated live
contention, or failure injection at every State write boundary.

Keep the optional lifecycle APIs launch-enabled. For each enabled route family,
retain an independent tracked feature flag, prove the flag can disable it, and
require public health and the emergency rollback path to report the expected
effective state.

## 7. Production-launch gates

Production remains disabled until all gates below are satisfied.

### 7.1 Repository and documentation cleanup

- Remove the scope-excluded harnesses, experimental-kernel framework, and stale
  instructions that would tell a later agent to rebuild them.
- Remove historical run narratives, failed-attempt stories, and superseded
  diagnostic artifacts that are not consumed by current operation.
- Keep canonical replay inputs, current infrastructure identifiers and scopes,
  current rollback instructions, and tests protecting live behavior.

### 7.2 Disabled-state baseline

Read-only verification must establish the current exact versions and that:

- production intake is effectively disabled;
- general and production replay are disabled;
- automatic publication is disabled;
- public lifecycle gates have not been enabled accidentally;
- the protected State heads and tracked runtime pins are coherent; and
- the live leaderboard still shows statements, stable problem URLs, group
  views, and representative solution metadata.

### 7.3 Credential and key boundary

- Repair the staging release OIDC trust mismatch through a reviewed,
  fail-closed infrastructure change.
- Complete one credentialed staging unwrap and reconstruction for an accepted
  staging archive with publication and production permissions disabled.
- Prove exact one-submission scope, consume-before-unwrap, reuse refusal,
  authority removal, source allowlisting, no plaintext artifact, and cleanup.
- Connect and verify the production archive **Wrap-only** role required for new
  intake. It must have no unwrap permission.
- Reverify the production release role's trust and scope without decrypting or
  publishing a production archive during preflight.

Historical legacy-archive migration is not a launch gate for new submissions.

### 7.4 Entry page and bounded lifecycle smoke

- Publish and verify the no-DNS entry page.
- At exact deployed submissions commit
  `f03f5cde4f1ac83b13ce78f294fc2273980dbf0a`, complete one browser and one
  source-bound headless submission through schema-version-3 archive before
  evaluation, terminal evaluation, immutable Result, and append-only State.
- Accept the green repository tests and retained prior bounded staging route
  evidence for metadata backfill, repair/retraction, maintainer decisions, and
  model alias/rename. Do not require a new exact-f03 live route-family matrix.
- Use the credentialed, publication-disabled staging reconstruction already
  required by section 7.3; do not repeat it solely to bind it to f03.
- Restore intake and every public lifecycle gate to disabled, verify effective
  health and State, and clean up the temporary staging proof, tag, and branch.
- Prove the live private-to-scheduled publication opt-in and its atomic release
  schedule on the packet-bound production canary in section 8, before public
  announcement.

For this gate, the exact launch candidate is the submissions commit deployed
for the lifecycle-API launch step. The later single-purpose intake-enable
commit is verified separately by the protected staging promotion canary,
finite-lease transition, and health and State readbacks in section 8; it does
not require repeating the browser/headless smoke or any optional route-family
case. Historical image and profile commits are independent of this gate.

### 7.5 Production launch readiness packet

Prepare a compact packet containing:

- exact repository commits and deployed versions;
- current feature-flag states;
- the section 7.2-7.4 results;
- credential owners, scopes, rotation, and revocation;
- OAuth ownership and recovery information;
- submitter-facing security, licensing, and release-policy text;
- rollback and emergency-pause instructions;
- deferred functionality and known limitations; and
- the issue-intake overlap announcement.

The maintainer's standing authorization in section 11 covers production
capability enablement once this packet is complete. The packet must still make
the release controller, lifecycle APIs, intake and production canary, and
overlap announcement separately visible. Standing authorization does not waive
any packet item, launch precondition, verification, pause, or rollback step.

## 8. Launch and overlap

After the launch packet is complete, make capability changes separately:

1. enable the automatic release controller initially when no release is due;
2. enable the approved lifecycle route families;
3. enable production intake through the finite-lease controller; and
4. submit the packet-bound production canary as private, verify archive,
   evaluation, Result, State, and the private leaderboard presentation, then
   exercise the visible irreversible publication opt-in and verify its atomic
   release schedule and scheduled presentation;
5. prove the production emergency pause and ordered restore; and
6. verify the public entry path, effective health, State consistency, release
   scheduling, and leaderboard presentation before announcing server intake.

Do not mix refactoring, replay expansion, documentation cleanup, or unrelated
features into an enablement change.

The four-week issue-intake overlap begins only when server intake is publicly
announced. During the overlap:

- keep issue intake available;
- monitor severity-high incidents, State consistency, archive completion,
  release scheduling, submitter adoption, and the first automatic releases;
- pause new server intake through the documented disable path if safety
  evidence fails; and
- extend the overlap if a serious incident or inadequate adoption makes closure
  unreasonable.

## 9. Historical completion after launch

Historical work may proceed in parallel with the overlap and other completion
lanes, but it does not delay initial production launch.

### 9.1 Freeze and classify the legacy corpus

- Preserve the completed 128-problem v1 baseline and its exact problem-set and
  queue bindings.
- Bind the current non-v1 campaign to exact State queue digests, and freeze a
  final Results/State delta when issue intake closes so later server Results
  cannot silently expand the historical campaign.
- Every accepted legacy result in that frozen scope must be classified as
  Git-source replayable, retained-archive replayable with its original source
  visibility preserved, or unavailable for a reviewed reason. For unresolved
  records, a failed source URL does not establish permanent unavailability
  while an exact retained archive remains recoverable.
- Use the smallest existing State event mechanism capable of recording the
  terminal disposition. Do not create a new aggregate transaction system unless
  an actual atomicity requirement is demonstrated.

### 9.2 Retained archive migration

- Reconcile every recoverable legacy archive/result binding and the explicit
  orphan set, including originally public sources recovered from their exact
  retained snapshots.
- Use a dedicated migration Wrap role and custodian-supplied legacy identity.
- Rewrap the per-submission data key without changing archive bytes or stable
  IDs.
- Preserve original public/private visibility and publication consent. An
  archive snapshot is not a reconstructed Git commit or source tree.
- Verify the result; do not retain plaintext or migration credentials.

Recovering an existing queued public task through its archive requires a
reviewed, versioned source-recovery transition under its original authority.
Preserve its Result and task identities, original source provenance,
benchmark, toolchain, checker, measurement configuration and attempt count.
Do not fabricate a failure or unavailable event to make that transition fit an
older schema. Prepare compatible State and consumer contracts together, pause
controllers, and prove no replay is running before switching readers. Queued
work and the completed frozen v1 dispositions remain intact. This is a finite
execution-method repair within the existing corpus, not a new replay service.

### 9.3 Replay execution

- Build or qualify only exact images needed by replayable results.
- Restore exact original source and benchmark pins. Never silently substitute a
  newer toolchain.
- Execute the ordinary official-kernel build and nanoda check with bounded
  retries and explicit terminal outcomes.
- Publish the redacted verdict and measurement projection to the leaderboard.
- Retain versioned checker identity/revision fields for future replay projects.

Historical completion for this overhaul means every legacy result recorded
before issue intake closes has a terminal replay record or reviewed unavailable
reason. As specified in section 3.4 and the retained plan, a terminal record may
report orchestration failure under the bounded retry policy; it must never be
presented as checker acceptance, successful replay verification or reviewed
unavailability. This clarification authorizes no retry-cap increase, attempt
reset or reopening of the frozen v1 baseline.

The campaign must use the retained ordinary official-kernel-plus-nanoda
path, may restore only finite task-scoped controller machinery, and must remove
that machinery again after both queues and the final cutoff delta are terminal.

## 10. Open problems, editorial work, and retirement

### 10.1 Open problems

- Use the neutral name **open problems**.
- Launching the tab with zero problems is acceptable.
- Do not add an importer, external synchronization, disproof semantics, or FC
  dependency.
- Future content is an ordinary LeanEval-owned catalog decision outside this
  overhaul.

### 10.2 Software verification and editorial work

- Verify that the two reviewed software-verification drafts render correctly
  with their draft/provisional policy.
- Complete human review of statements, citations, and background according to
  maintainer availability.
- Keep hints human-written.
- Do not build verified-calculation execution infrastructure in this overhaul.

### 10.3 Issue-intake retirement

After at least four weeks of announced overlap, close issue intake only if:

- there is no unresolved severity-high incident;
- server intake, archive, evaluation, release scheduling, and leaderboard
  presentation are stable;
- submitter adoption is adequate;
- at least two weeks of public closure notice has been given; and
- the frozen v1 historical scope and its terminal dispositions remain
  recorded.

## 11. Repository and authorization boundary

Autonomous implementation is allowed only in this LeanEval repository family:

- `leanprover/lean-eval`;
- `leanprover/lean-eval-submissions`;
- `leanprover/lean-eval-leaderboard`;
- `leanprover/lean-eval-state`;
- `leanprover/lean-eval-state-staging`;
- `leanprover/lean-eval-releases`;
- `leanprover/lean-eval-generator`; and
- `leanprover/lean-eval-audit` (private).

Within that allowlist, agents may autonomously inspect, implement, test, create
branches and pull requests, address review, merge after required checks, and
run ordinary repository CI.

Standing maintainer authorization, recorded on 2026-08-29, preapproves every
remaining operation required by this completion plan. This includes
infrastructure and protected-environment changes, credential creation or
mutation, production capability enablement, production canaries, canonical
data writes and migrations, issue-intake retirement, announcements, and
external non-PR mutations. Do not interrupt the maintainer merely to renew
permission for one of these in-scope operations.

Standing authorization satisfies permission, not readiness. Before each
high-impact operation, complete the exact packet or checklist required by this
plan and the runbook: bind targets, immutable inputs, scopes, user impact,
preconditions, rollback or fail-closed recovery, and post-change verification.
Keep changes single-purpose, preserve credential confidentiality, use the
smallest sufficient authority, and stop rather than proceeding when a required
precondition is false or the proposed action exceeds the reviewed packet.

Only these actions still require exact maintainer approval:

1. opening, updating, or merging a pull request in a repository outside the
   allowlist;
2. posting a Zulip message or comment;
3. posting a comment or review on another person's pull request; and
4. any product-scope expansion beyond this completion plan.

External non-PR actions required by the accepted scope are covered by standing
authorization, including issues, announcements outside Zulip, and bounded
runtime identity-proof mutations. This does not authorize an external pull
request or an unrelated external change.

An authenticated maintainer action needed because the agent lacks access is an
operator handoff, not an approval gate. Present the reviewed command and its
expected readback, but do not describe the maintainer's login as permission for
an otherwise authorized change. Rollback and credential revocation remain
subject to the same impact analysis, packet bounds, and verification as the
forward change.

## 12. Recordkeeping policy

Repository documentation should contain current contracts, current state,
current operating instructions, and canonical data needed to finish the
product. It should not become a chronicle of agent activity.

- Do not add run-by-run evidence tables, failed-attempt stories, shard
  provenance essays, or “war stories.” Git, PRs, and Actions retain that
  history.
- Update a status or identifier in place when the current operational fact
  changes.
- Keep only canonical machine-readable historical inventories, plans,
  mappings, and unavailable classifications that are still consumed.
- Delete a superseded object after no current plan, profile, rollback, or
  migration input references it.
- Record a test or run link in a PR when useful; do not duplicate it into a
  permanent ledger unless it is itself a current operational identifier.

## 13. Final completion criteria

The lifecycle overhaul is finished when all of the following are true:

- production server intake is the supported intake path;
- new submissions archive before evaluation with per-submission envelopes;
- accepted and rejected lifecycle transitions are coherent and recoverable;
- automatic two-calendar-month releases are operating with initial
  scheduled/private choice and one-way private-to-scheduled opt-in;
- the production canary's first automatic release has published successfully
  at or after its exact two-calendar-month due timestamp;
- the launch-approved backfill, repair/retraction, maintainer, alias, and rename
  functions are available;
- the leaderboard correctly exposes lifecycle, statements, standings,
  metadata, statistics, and released solutions;
- every legacy accepted result recorded before issue intake closes has a
  terminal replay or unavailable disposition using the official kernel and
  nanoda;
- the neutral open-problems tab exists, even if empty;
- the software-verification drafts and agreed editorial state are visible;
- the four-week overlap and notice gates have passed and issue intake is
  closed;
- current rollback and pause procedures have been verified; and
- the repository contains no known instructions to resume scope-excluded FC,
  disproof, experimental-kernel, or persistent-qualification work.
