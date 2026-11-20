# LeanEval lifecycle overhaul execution runbook

Status: **active companion to the completion plan**  
Scope authority: [`overhaul-completion-plan.md`](overhaul-completion-plan.md)

## 1. Purpose

This runbook is the operational checklist for finishing the lifecycle overhaul.
It is intentionally updateable: check items off, replace stale current-state
values, and keep the next action obvious. Do not use it to add product scope.

Before acting, read the completion plan in full. If an old tracker, branch,
comment, or original-plan clause conflicts with it, the completion plan wins.

## 2. Starting posture

At adoption, the intended safe posture is:

- production intake disabled;
- staging general replay disabled except for bounded isolated work;
- production replay disabled;
- automatic publication disabled;
- public result-owner, maintainer, and model-identity gates disabled;
- the lifecycle-aware leaderboard live with problem statements visible; and
- no FC, disproof, or experimental-kernel work authorized.

Do not trust this paragraph as a live probe. Phase 1 re-verifies it read-only
and updates the current infrastructure inventory in place if necessary.

## 3. Execution rules

### 3.1 Work autonomously inside the allowlist

Repository implementation, tests, PRs, review fixes, merges, ordinary CI, and
automatic disabled-state deployments are autonomous in the repository family
listed in completion-plan section 11.

Standing maintainer authorization covers every remaining in-scope operation,
including infrastructure, credentials, protected environments, production
enablement, canonical data, issue-intake retirement, announcements, and
external non-PR mutations. Complete the applicable impact packet, preconditions,
tests, rollback, and post-change verification before acting; standing approval
does not make an unready operation ready. Do not turn a missing local login
into a permission question: prepare an operator handoff when authenticated
execution is required.

Parallelize independent repository work and use build time productively. Do not
sit polling one workflow while other in-scope tasks can advance.

### 3.2 Standing authorization and remaining stop conditions

Do not request repeated approval for an operation already covered by the
standing authorization in completion-plan section 11. The production-launch,
historical migration/replay, and issue-retirement packets remain mandatory
readiness gates; complete and review them without waiting for another
permission response.

Stop for exact maintainer approval only before:

- opening, updating, or merging a pull request in a repository outside the
  allowlist;
- posting a Zulip message or comment;
- posting a comment or review on another person's pull request; or
- expanding the completion-plan scope.

At any high-impact readiness gate, record the exact mutation, target, user
impact, immutable inputs, rollback, and read-only precondition. A fail-closed
capability disable or credential revocation may proceed immediately, but its
impact and verification requirements are not waived. Other rollback follows
the same rules as its forward change.

### 3.3 Keep changes reviewable

- One coherent purpose per PR.
- Do not mix feature enablement with cleanup or refactoring.
- Preserve unrelated work in dirty worktrees.
- Do not weaken security checks merely to make a smoke pass.
- Do not add a new framework when a bounded script or existing mechanism is
  sufficient.
- Merge only after required checks are green and review threads are resolved.

### 3.4 Record current state, not a narrative

- Check off the item and update the current identifier or state.
- Do not append run-by-run histories or incident prose.
- Keep GitHub run links in the PR or handoff message.
- Retain only canonical machine-readable inputs consumed by later phases.

## 4. Phase 0 — rebaseline and delete overgrowth

Goal: make the repositories describe only the approved remaining program.

- [x] Inventory every open PR, active workflow, remote branch, and relevant
      local worktree in the allowlisted repositories.
- [x] Confirm the already identified escaped external branches are absent and
      the stale LeanEval PRs are closed.
- [x] Review any uncommitted local cleanup attempt as an untrusted candidate
      diff. Keep useful pieces only after comparing them with current upstream.
- [x] Delete the persistent model-identity qualification harness, private
      qualification Workers, workflows, generated types, fixtures, tests, and
      rebuild/recovery instructions.
- [x] Delete experimental-kernel shadow smoke, Arena/Mathgraph assets,
      checker-series and corpus-promotion machinery, wire/attestation protocols,
      candidate adapters, and tests that exist only for them.
- [x] Remove exact-byte solution-export capture hooks that existed only to feed
      the removed experimental-kernel lane.
- [x] Retain the existing official Lean build and nanoda replay path, its
      generic checker identity/revision fields, and its focused tests.
- [x] Preserve source-bound agent sessions, authorization boundaries,
      idempotency, CAS conflict handling, and other generally useful security
      hardening.
- [x] Remove superseded run narratives, diagnostic artifacts, and tests whose
      only purpose is preserving those narratives.
- [x] Retain canonical replay inventories, final plans, exact toolchain/source
      maps, unavailable-candidate data, current rollback contracts, and current
      infrastructure identifiers.
- [x] Retain an older canonical input set only while a live execution profile
      references it; delete the whole linked set after replacement.
- [x] Rewrite the submissions tracker, rollout runbook, and infrastructure
      inventory to current state and remaining gates, without a chronology.
- [x] Run repository tests, typechecks, linters with zero warnings, workflow
      validation, action-pin audit, and all relevant dry-runs.
- [x] Merge the cleanup in coherent repository-local PRs.

Exit condition: no tracked instruction tells a future agent to implement FC,
disproofs, experimental kernels, or the persistent qualification harness.

## 5. Phase 1 — read-only disabled-state reconciliation

Goal: establish one exact safe baseline before launch work resumes.

### 5.1 Repositories and automation

- [x] Record the protected `main` commits at reconciliation and retain stable
      component checkpoints for later operational bindings.
- [x] List open PRs and cross-referenced work; close or classify stale overhaul
      PRs.
- [x] Confirm no unplanned workflow dispatch is queued or running.
- [x] Confirm required checks, protected branches, and immutable dispatch-tag
      protections match current operating needs.

The table records durable component checkpoints, not the moving tip of an
append-only repository. Later Results-only or State-only descendants do not
invalidate these bindings. Section 5.2 records the deployed runtime separately.

| Repository | Durable checkpoint | Protection state |
| --- | --- | --- |
| `lean-eval` | Completion-plan and runbook checkpoint `59c0c18b2d14015589927b6e810386025c93ba4b` | Required `verify` |
| `lean-eval-submissions` | Protected main and deployed production Worker `27fe540135dfcc6c0e21fccf3ab0f9eff51d49d8` | Required `verify` |
| `lean-eval-leaderboard` | Protected and deployed main `72fc27fb8f302b38a2741831130fd73f4dcfc41a` | Required `build`; exact Pages deployment and live readback complete |
| `lean-eval-state` | Retained-baseline checkpoint `76b3b3e54f4be69161a00cd81576a58df8eae815` | Required `validate`; append-only descendants allowed |
| `lean-eval-state-staging` | Launch-acceptance checkpoint `0849a95026ea3491ec55f1e0ef3b6ff2dff00fd5` | Required `validate`; append-only descendants allowed |
| `lean-eval-releases` | `7dba9bf4f78c71ff478de8c593cb41e07201c14a` | Required `validate` |
| `lean-eval-generator` | `010b01634cccda2db538cf9b09e6f26ddc453743` | Required `check` |
| `lean-eval-audit` | `d73132415738b0d82c99fd43f630804fe996e342` | Reviewed changes; non-rewritable linear history |

### 5.2 Deployed services

Production serves deployed submissions implementation
`27fe540135dfcc6c0e21fccf3ab0f9eff51d49d8` with durable intake and exactly
the approved lifecycle routes enabled. Deployment, CI, readiness, health, and
protected-State validation pass.
Staging intake and public lifecycle routes remain disabled, with its promotion
canary enabled. Model consolidation, publication opt-out, production promotion
canary, and general replay remain disabled.

The frozen v1 public and private replay scopes are terminal. Production State
validates with no historical replay running, controller variables are absent,
and no task-scoped private Worker or container application remains. Temporary
replay controllers and qualification machinery have been removed; canonical
archives, plans, pins, schemas, and terminal State remain for reproducibility.

Leaderboard commit `72fc27fb8f302b38a2741831130fd73f4dcfc41a` is protected and
deployed. The live submit entry directs users to the production service,
requires both read-only Apps, recommends scheduled release by default, and
retains the dated issue-intake fallback. A representative problem page retains
its visible statement.

Release-role trust and the automatic controller are live at releases checkpoint
`7dba9bf4f78c71ff478de8c593cb41e07201c14a`. The migrated archive checkpoint is
audit `d73132415738b0d82c99fd43f630804fe996e342`. The launch canary is terminal
and scheduled for `2026-11-02T03:50:01.002Z`; temporary source access is absent.
The server-primary entry is live. The overlap began
`2026-09-02T06:57:10Z`, so issue intake cannot close before
`2026-09-30T06:57:10Z` or before its separate notice and readiness gates pass.

- [x] Read staging and production intake health.
- [x] Read staging and production broker/replay health and current versions.
- [x] Verify production serves deployed implementation
      `27fe540135dfcc6c0e21fccf3ab0f9eff51d49d8` and reports durable intake plus
      exactly the approved lifecycle routes.
- [x] Verify general replay is disabled and historical replay-controller
      variables are absent.
- [x] Verify automatic publication remains live.
- [x] Verify the deployed launch Worker and its release, archive, and
      retained-State checkpoints form one coherent unit.

### 5.3 State, credentials, and presentation

- [x] Verify protected State heads and validation status.
- [x] Inventory credential names, owners, scopes, expiry, rotation, and
      revocation without exposing values.
- [x] Confirm production State contains no unexpected accepted server
      submission or due release work.
- [x] Confirm the live leaderboard root, group tabs, stable problem URLs,
      problem statements, and representative solution metadata.
- [x] Confirm the scheduled-release presentation deploys from reviewed main and
      the canonical live asset is byte-identical.
- [x] Verify leaderboard commit
      `72fc27fb8f302b38a2741831130fd73f4dcfc41a` is the exact live Pages
      deployment.

Exit condition: the coherent disabled baseline was captured before launch.
Section 5.2 now records the live launch posture; a future mismatch becomes a
separate repository fix or infrastructure correction under standing
authorization.

## 6. Phase 2 — repository launch preparation

These lanes can proceed in parallel after Phase 1.

### 6.1 No-DNS submission entry

- [x] Add `https://lean-lang.org/eval/submit/` to the leaderboard site.
- [x] Explain that authentication continues on the LeanEval Worker origin.
- [x] Link to the production `workers.dev` application.
- [x] Verify navigation, accessibility, mobile layout, and return path to the
      leaderboard.
- [x] Keep OAuth callback and session handling on the Worker origin.

### 6.2 Release and archive repository preparation

- [x] Reconfirm the exact staging release OIDC trust mismatch.
- [x] Prepare the smallest reviewed infrastructure patch or operator command;
      do not apply it yet.
- [x] Reconfirm the production archive Wrap-only role requirement and prove the
      desired policy excludes unwrap.
- [x] Verify the release controller reconstructs deterministically with
      publication disabled using credential-free fixtures.
- [x] Verify submitter-facing license, release delay, initial private choice,
      and irreversible later opt-in language.
- [x] Keep publication opt-out disabled and absent from user-facing forms and
      documentation.

### 6.3 Lifecycle API launch surface

- [x] Confirm feature flags exist independently for the route families being
      launched.
- [x] Keep model consolidation disabled or remove it.
- [x] Run all existing repository tests.
- [x] Prepare the bounded success and authorization/validation fixtures required
      by the completion plan for each launch route family:
  - [x] metadata backfill;
  - [x] repair/retraction request;
  - [x] maintainer decision;
  - [x] model alias/rename; and
  - [x] publication opt-in success, including post-result atomic scheduling.
- [x] Accept the green repository tests and retained prior bounded staging
      route evidence as the prelaunch evidence for backfill,
      repair/retraction, maintainer decisions, and model alias/rename. Do not
      run a fresh exact-f03 live matrix for those optional routes.
- [x] Move the required live publication-opt-in proof to the packet-bound
      production canary; keep its focused repository coverage green before
      launch.
- [x] Verify every launch gate can be returned to disabled and health reports
      the effective state.
- [x] Do not build a persistent staging harness.

### 6.4 Exact-version core lifecycle rehearsal

The operational-baseline table in section 5.1 records the current repository
family. The exact final-rehearsal staging basis was
`f03f5cde4f1ac83b13ce78f294fc2273980dbf0a`, with immutable tag
`lean-eval-dispatch/f03f5cde4f1ac83b13ce78f294fc2273980dbf0a`.
Protected CI, staging deployment, and promotion canary pass. Protected releases
commit `c0bcb97d87eeb17c0a2f1ef7e8bfc76502deb798` remains the credentialed,
publication-disabled staging reconstruction fixture qualified by section 7.
The bounded final core smoke, all-false restoration, validation, and fixture
cleanup are complete.
Launch restore commit `39b2e67f7583926a4f1d66b723b5d4cf4756dd32`
completed the production launch. Current deployed descendant
`0aef118adbe2e2e48917827839c6b37714cc7c50` retains that contract. Its
production deployment and exact live
readbacks pass; later documentation-only commits do not by themselves redeploy
that runtime.

Historical private-image preparation is independent of the deployed staging
and production Worker. Its retained artifacts do not define the launch binding,
and the historical lane remains outside the completed launch gate.

- [x] Bind the exact final candidate commits across the repository family.
- [x] Use a synthetic private source repository owned for staging.
- [x] Move the final source fixture to a temporary, non-default fixture branch
      in private allowlisted `lean-eval-state-staging`.
- [x] Select the private staging fixture repository in both contents-read org
      App installations, preflight both Apps against that branch, use a
      runtime-unique tag, and remove the staging branch and tag after the
      terminal run. The separately tracked production canary uses its own
      fixture branch in the same private repository; Phase 4 owns its terminal
      branch and App-access cleanup.
- [x] Retain the exact secret-Gist proof because it binds the headless request
      to the individual GitHub login. Apply only the exact runtime-generated
      Gist file CAS write/restore under standing authorization.
- [x] Prepare one browser and one source-bound headless submission.
- [x] Retain repository coverage and prior bounded staging evidence for invalid
      and unauthorized optional-route cases.
- [x] Confirm archive-before-evaluation and schema-version-3 binding against
      the exact final candidate for both browser and headless submissions.
- [x] Confirm both exact-candidate core paths produce immutable Results and
      append-only State, including the initially scheduled headless release
      readiness and redacted projection.
- [x] Do not require an exact-f03 live matrix for metadata backfill,
      repair/retraction, maintainer decisions, model alias/rename, or
      publication opt-in. The production canary owns the live opt-in proof.
- [x] Prepare the rollback/disable steps for the same exact version.

Exit condition: repository changes and staging fixtures are ready; bounded
external mutations occur only at their exact runtime step.

## 7. Autonomous credential-boundary preparation

The staging boundary has been exercised with production and publication
authority absent:

- [x] Apply only the reviewed staging trust change.
- [x] Run one credentialed staging release unwrap and reconstruction.
- [x] Verify consume-before-unwrap and identical reuse refusal.
- [x] Remove AWS authority before reconstruction execution.
- [x] Verify source allowlist, no plaintext artifact, no State/Git mutation,
      and cleanup.
- [x] Confirm the one-use grant was consumed and workflow AWS credentials were
      cleared before reconstruction.

Complete the production **Wrap-only** connection autonomously while intake
remains disabled:

Current qualification: the immutable-tag production Wrap-only preflight
passes, including an actual synthetic Encrypt and an explicit Decrypt denial.

- [x] Connect repository environment
      `archive-production` variable `AWS_WRAP_ROLE_ARN` to
      `arn:aws:iam::161072922960:role/lean-eval-archive-wrap-production`.
- [x] Dispatch the immutable-tag preflight that encrypts a synthetic key for the
      exact production archive subject.
- [x] Require that same preflight to prove decrypt is denied.
- [x] Do not accept a production submission during this preflight.

Complete the isolated production release-role trust repair autonomously while
publication remains disabled:

At protected releases head
`7dba9bf4f78c71ff478de8c593cb41e07201c14a`, the release role trusts only the
exact ID-bearing production environment subject. The exact current-State
projection and write-free no-op preflight are protected, and
`PUBLICATION_ENABLED=true` after the successful no-due-work controller
qualification.

- [x] Change only the trust on
      `lean-eval-release-unwrap-invoker-production` from the obsolete name-only
      subject to
      `repo:leanprover@7233018/lean-eval-releases@1340741242:environment:release-production`.
- [x] Run the trust-only production preflight with `PUBLICATION_ENABLED` absent.
- [x] Confirm the preflight has no archive, State, Git, or artifact write path.
- [x] Keep `PUBLICATION_ENABLED` absent until the release-controller launch
      action; it is now enabled under Phase 4.

Exit condition: new production submissions can receive safe envelopes and the
release path has passed a credentialed staging boundary.

## 8. Phase 3 — final staging acceptance

The exact-f03 final acceptance is complete. It was limited to the browser and
source-bound headless core paths; optional lifecycle route families require no
new live matrix. Protected submissions commit
`f03f5cde4f1ac83b13ce78f294fc2273980dbf0a`, its immutable tag, staging
deployment, promotion canary, and both core paths pass. Staging intake and all
public lifecycle gates are false, model consolidation and publication opt-out
remain false, and the promotion canary is intentionally true. The watchdog is
cancelled, the temporary staging branch and tag are absent, and the exact
identity proof is restored. Protected releases commit
`c0bcb97d87eeb17c0a2f1ef7e8bfc76502deb798` remains the already qualified
publication-disabled staging reconstruction fixture.

- [x] Merge and deploy the exact final candidate through the normal protected
      path and qualify the corrected bounded-smoke workflow.
- [x] Reconcile the exact-f03 browser and source-bound headless submissions
      through archive-before-evaluation, terminal evaluation, immutable Result,
      append-only State, and release readiness where selected.
- [x] Run the all-false recovery and fixture cleanup; verify public-health
      readback, staging State validation, and absence of exposed source or
      credential material.

Do not rerun broad historical matrices merely to obtain newer timestamps.

## 9. Production launch readiness gate

Prepare the compact launch readiness packet specified by completion-plan
section 7.5.

Standing authorization for these operations is recorded in completion-plan
section 11. Before packet `GO`, confirm that it binds these launch components
as separate planned actions:

- [x] automatic release controller enablement and readback;
- [x] approved public lifecycle API enablement and readback;
- [x] production intake enablement plus one named production canary with
      permanent archive, Result, State, and release-schedule records; and
- [x] the exact overlap-announcement requirements and separately gated launch
      copy.

Do not launch until every prelaunch packet item and precondition is satisfied.
The packet's explicitly identified post-action finalization fields remain open
at `GO` and are filled after each corresponding Phase 4 action. Standing
authorization removes another permission interruption; it does not allow a
green staging run to substitute for launch readiness.

The compact launch packet is protected in submissions migration head
`7050f0e100323070375bc58c3510ec322cfcce1e`. The reviewed launch restore is
`39b2e67f7583926a4f1d66b723b5d4cf4756dd32`; deployed descendant
`0aef118adbe2e2e48917827839c6b37714cc7c50` retains its contract. Exact
deployed-commit, capability, authorization-denial, and protected-State readbacks
pass.

Historical completion, overlap elapsed time, issue-closure notice, and the
canary's later release date remain required for full overhaul completion.

## 10. Phase 4 — launch

After the launch packet is complete:

### 10.1 Release controller

- [x] Confirm no release is currently due.
- [x] Enable the controller in a single-purpose change.
- [x] Verify configuration, protected State access, and publication posture at
      releases `7dba9bf4f78c71ff478de8c593cb41e07201c14a`; no source is
      currently due.

Automatic publication is live. Both the repository and `release-production`
environment latches read back `true`. The controller's reviewed State contract
accepts the current append-only descendant while retaining exact schema and
script tree checks; the protected-main integration, publication-disabled
write-free no-op, and enabled no-due-work pass all succeed.

### 10.2 Lifecycle APIs

- [x] Configure only backfill, repair/retraction, maintainer decisions,
      alias/rename, and one-way publication opt-in. The reverse publication
      transition must remain unavailable, disabled, and absent from
      user-facing forms and documentation.
- [x] Keep model consolidation disabled.
- [x] Verify effective public health and one non-mutating authorization denial
      against deployed submissions `0aef118adbe2e2e48917827839c6b37714cc7c50`.
- [x] Retain a separately reversible feature flag for every enabled family and
      verify the all-false rollback; do not substitute another staging matrix
      for this production readback.

### 10.3 Intake

- [x] Enable production intake durably at launch restore
      `39b2e67f7583926a4f1d66b723b5d4cf4756dd32`; verify current deployed
      descendant `0aef118adbe2e2e48917827839c6b37714cc7c50` retains it.
- [x] Verify the exact active version, durable state, and
      protected State coherence.
- [x] Submit one tightly controlled production canary only if it was part of
      the reviewed launch packet.
- [x] Verify archive completion, evaluation dispatch, State, and Result.
- [x] Verify the initial live leaderboard presentation shows the canary exactly
      once, keeps its source unavailable, and preserves the problem statement.
- [x] Verify release scheduling after the one-way publication opt-in. State
      `fb079f6c3b96388eebe106ea2938d0c2231694ba` records revision 1 as
      `scheduled`, due exactly `2026-11-02T03:50:01.002Z`.
- [x] Use the packet-bound visible archived problem and exact previously
      accepted Kim-owned source with a distinct canary model identity.
- [x] Submit the canary as private, verify that choice on the live problem page,
      then perform the required live proof of the visible irreversible
      publication opt-in. The same atomic State append creates its release
      schedule.
- [x] Complete the immediate leaderboard refresh and verify the scheduled
      choice, release timestamp, exact State commit, and unavailable source on
      the live page.
- [x] Keep the periodic read-only leaderboard State-drift deployment path
      active so later State-only lifecycle events cannot leave the public site
      stale indefinitely.
- [x] On success, delete the exact private canary branch and remove the private
      fixture repository from both source App selections; on failure, run the
      all-false recovery, pause publication, and retain those dependencies
      until the submission reaches a reviewed terminal state.
- [x] Before announcing the server, exercise the emergency pause against the
      exact deployed production version: disable intake and every lifecycle
      gate, remove the publication latch, and verify effective health, a
      write-free release-controller pass, and unchanged protected State.
- [x] Restore the same reviewed release, lifecycle, and intake settings as
      separate actions in that order, repeating the effective-health and
      protected-State readbacks after each action. Do not substitute the
      earlier staging rollback for this current-production proof.

### 10.4 Announcement

- [x] Publish the server entry path and four-week overlap dates.
- [x] State that issue intake remains available during the overlap.
- [x] State that any eventual issue-intake closure requires at least two weeks'
      notice.

### 10.5 Post-launch P0/P1 hardening

- [x] Make server submissions evaluate only the catalog problem and statement
      revision accepted into State; keep workspace scanning only in the
      temporary legacy issue lane.
- [x] Align the public State projection and leaderboard adapter on all current
      historical counter-unavailability reasons.
- [x] Add immutable exact-submission claims and per-owner intake indexes to
      both production and staging State.
- [x] Deploy clean-break intake API schema version 2. The server resolves group
      and revision from protected benchmark `main`, requires current terms,
      rejects withheld publication for public repositories, deduplicates exact
      submissions, and permits at most four active submissions per owner.
- [x] Update the submission service, stable submit page, and repository guide
      to describe the same contract and remove superseded overhaul narratives.
- [x] Read back production health and exercise one bounded exact submission
      after the hardened Worker is deployed.

Exit condition: the launch commit is live, new production submissions traverse
the promised lifecycle, and the system can be paused through the documented
path.

Lower-priority UX, performance, reliability, and cleanup findings are collected
in [lean-eval #634](https://github.com/leanprover/lean-eval/issues/634) for later
triage. They are not part of this overhaul unless the completion plan is
explicitly amended.

## 11. Phase 5 — four-week overlap

The overlap began `2026-09-02T06:57:10Z` and cannot end before
`2026-09-30T06:57:10Z`. The conditional issue-intake retirement target of that
same timestamp was announced at `2026-09-02T23:06:35Z`; its two-week notice
gate matures at `2026-09-16T23:06:35Z`. Retirement remains conditional on every
operational, adoption, final-corpus, and readiness gate below and must be
postponed if any is not satisfied. The canary's first automatic-release
checkpoint is `2026-11-02T03:50:01.002Z`. Full overhaul completion remains
blocked until these calendar gates and the operational checks below pass.

The repository variable `ISSUE_INTAKE_CUTOFF` is already installed and read
back as the exact announced timestamp `2026-09-30T06:57:10Z`. It has no effect
until the reviewed cutoff guard reaches protected `main`; merge that guard only
after the retained replay chains are terminal, then verify its protected-main
CI before the timestamp. Deleting the variable is the reversible incident
recovery that reopens issue intake before the form itself is retired.

- [ ] Monitor severity-high incidents and readiness failures.
- [ ] Monitor State validation, archive completion, evaluation dispatch,
      release scheduling, and automatic releases.
- [ ] At the first automatic controller cycle at or after the production
      canary's exact two-calendar-month due timestamp, verify its release task
      moves from scheduled to published, the reconstructed source commit and
      live leaderboard link agree, every submission still carrying the withheld
      choice remains unpublished, and no source or credential appears in public
      logs or artifacts. Pause publication on any mismatch; the final audit
      cannot complete before this checkpoint passes.
- [ ] Monitor submitter adoption of the new path.
- [ ] Keep issue intake available.
- [ ] Pause server intake if confidentiality, State consistency, or release
      safety fails.
- [ ] Extend the overlap rather than closing on schedule if a serious incident
      or inadequate adoption remains.
- [ ] Maintain the final append-only Results delta for issue submissions.

Do not turn monitoring output into a permanent incident-history appendix.

## 12. Phase 6 — historical completion

This overhaul's historical scope is every legacy accepted Result recorded
before issue intake closes. The completed v1 baseline remains bound to the
canonical v1 problem-set SHA-256
`546706914389696b93653189ba870550e9853a4ac653664f482ba8d4d9eb9492`.
The non-v1 queues are now part of completion under the same official-kernel and
nanoda policy. Issue intake remains open until the announced cutoff, so the
campaign has two finite parts: drain the current queues, then freeze and drain
the append-only cutoff delta.

The retained baseline inventory contains 1,301 accepted Result records, bound by
inventory SHA256 `bb405fbabe084e106ad5500b455a05ba1e1d54175d1964db3aebcc3b6ea3fce3`
in submissions' `evidence/historical-replay/inventories/` and Results source
`ae1a9714c5433b4c195b8fdfb5643893ecac8019`.
Inventory membership does not imply that every non-v1 replay is terminal. Keep
the completed frozen v1 task/disposition bindings immutable and finish the
remaining non-v1 work. The append-only delta after this inventory may grow
until issue intake is frozen; keep its classification and execution bindings
separate.

Terminal failed orchestration records remain failed records under the existing
bounded retry policy, including exhausted attempts. Report them separately
from checker acceptances and reviewed-unavailable dispositions; do not reset
attempts or invent an unavailable reason to empty a queue.

### 12.1 Frozen v1 scope

- [x] Freeze and validate the v1 problem-set binding.
- [x] Reconcile every in-scope accepted Result into public-source,
      private-archive, or reviewed-unavailable handling.
- [x] Retain canonical source, archive, toolchain, image, checker-version, and
      Result bindings needed for later reproducibility.
- [x] Confirm production State validates and has no running historical replay.

### 12.2 Public source

- [x] Retain the canonical public plan and exact source/toolchain mappings.
- [x] Build or qualify only images required by replayable v1 Results.
- [x] Run the official Lean kernel path and nanoda with bounded retries.
- [x] Record a terminal replay or reviewed-unavailable disposition for every
      public-source v1 Result.
- [x] Publish the redacted verdict and measurement projection.

### 12.3 Private archives

- [x] Reconcile exact archive/result bindings and explicit orphans.
- [x] Rewrap recoverable per-submission data keys without changing archive
      ciphertext bytes or stable IDs.
- [x] Build and inspect only the immutable images required by replayable v1
      Results.
- [x] Run the official Lean kernel path and nanoda with bounded retries.
- [x] Record a terminal replay or reviewed-unavailable disposition for every
      private-archive v1 Result.
- [x] Remove migration credentials and plaintext scratch material.
- [x] Retain canonical archive envelopes, crosswalks, image pins, and terminal
      State needed for future verification.

### 12.4 Replay

- [x] Confirm the public v1 planner and all four private v1 planners are empty.
- [x] Confirm production State has no running historical replay.
- [x] Disable the public and private historical controller gates.
- [x] Prove that no task-scoped private Worker or container application remains.
- [x] Delete the temporary controller, qualification, and resource-audit
      machinery after that resource proof succeeds.

The v1 baseline remains complete and immutable. Reopening replay for the
non-v1 campaign does not reopen or rewrite any v1 terminal record.

### 12.5 Non-v1 completion campaign

The initial campaign snapshot is production State
`1e52235612fec220be054bccb442325bcc9c9526`, whose 4,420-event source digest is
`20284ac890fa03b7a36e0491c8202d513562dcee656790ce83c02603788c9a57`.
It materializes 145 public tasks (144 queued and one retryable failure) and 562
queued private tasks. All 562 private tasks already use schema-version-3
envelopes; the largest plaintext archive is below 7 MB, so no archive transport
expansion is required. The tasks use 90 already reviewed execution profiles
across five historical Lean toolchains.

- [ ] Amend and merge the completion-plan scope before enabling replay.
- [ ] Restore only the finite public controller and four finite private lanes
      needed to drain the preserved queues; keep all controller gates dark by
      default.
- [ ] Revalidate the retained execution profiles, exact State/Audit bindings,
      OIDC and unwrap scope, network isolation, bounded retries, and terminal
      State writer before enabling the campaign.
- [ ] Drain the 145 public tasks through the official Lean path and nanoda,
      recording a terminal outcome or reviewed unavailability for each.
- [ ] Drain the 562 private tasks through the same checker path without
      retaining plaintext source, keys, credentials, or task-scoped resources.
- [ ] For unresolved public tasks whose Git source is inaccessible, reconcile
      any exact retained archive before unavailable classification. Prepare
      the separate retained-corpus migration, archive-capable profile and
      queued-source recovery bindings; preserve original public visibility,
      identities, provenance and attempts. Unresolved means queued or
      retryable-failed at the bound State head; existing unavailable and
      nonretryable-failed dispositions stay terminal. Hold the blocked task IDs
      out of dispatch, or pause the lane, until recovery is ready. Recovery
      neither schedules release nor publishes source or archive bytes. Only
      the existing archive controller receives exact task-bound single-use
      unwrap authority. Switch compatible State/consumer
      readers only with controllers paused and no running replay, then require
      the existing bounded first-real-task canary and cleanup checks before
      continuing each changed archive image's lane. The adapter may land while
      these blocked tasks stay queued.
- [ ] At the issue-intake cutoff, freeze the final Results/State delta and
      classify every additional legacy accepted Result.
- [ ] Migrate any recoverable retained legacy archive in that final delta to a
      per-submission envelope without changing archive bytes, stable IDs,
      original visibility or publication consent. This includes originally
      public sources recovered from exact retained snapshots.
- [ ] Drain the final public and private delta and prove both planners empty,
      production State valid, and no historical replay running.
- [ ] Disable the replay gates and delete the temporary controller, runner,
      qualification, and resource-audit machinery and all task-scoped cloud
      resources.

No experimental checker, persistent qualification service, or replay of
ordinary server-intake submissions is part of this campaign.

### 12.6 Retained future-replay boundary

- [x] Keep schema-version-3 archives, canonical migration inputs, and the
      ordinary v1/v2 unwrap and replay path.
- [x] Keep the legacy identity absent from GitHub and remove transient identity
      and plaintext scratch material.
- [x] Leave the dedicated Encrypt-only migration role and protected environment
      dormant except for the separately bounded retained-corpus recovery and
      final-delta migrations. Each requires its exact reviewed selection and
      preservation checks, and removal of the installed custodian identity
      after the run. Neither role nor environment has replay, production
      intake, release, or State-write authority.
- [x] Keep the offline legacy identity under custodian control. Its eventual
      destruction is an explicit future custodian decision, not part of this
      overhaul.

## 13. Phase 7 — remaining product completion

### 13.1 Open problems

- [x] Add or verify the neutral open-problems tab.
- [x] Confirm the empty state is clear and visually intentional.
- [x] Confirm it has no FC branding, importer, synchronization, or disproof
      dependency.

### 13.2 Software verification and editorial state

- [x] Verify both reviewed software-verification drafts render correctly.
- [x] Verify provisional/draft policy text.
- [x] Complete the maintainer-selected human statement/citation review.
- [x] Confirm no agent-authored hints were introduced.
- [x] Leave verified-calculation runner infrastructure unimplemented.

### 13.3 Final leaderboard readback

- [x] Confirm lifecycle, stable problem URLs, statements, unique and total
      standings, recent solutions, and metadata provenance are presented.
- [ ] Confirm one live automatic released-solution link and representative
      historical replay measurements after those operational lanes complete.
      No further repository feature work is pending for this surface.

### 13.4 Retire issue intake

- [ ] Confirm at least four weeks of announced overlap.
- [ ] Confirm at least two weeks of closure notice.
- [ ] Confirm no unresolved severity-high incident.
- [ ] Confirm adequate adoption and stable end-to-end operation.
- [ ] Confirm every legacy accepted Result through the issue-intake cutoff has
      a terminal replay or reviewed-unavailable disposition.
- [ ] Freeze issue intake at the announced cutoff. Keep the public issue form
      frozen but present until the retirement packet passes.
- [ ] Complete the issue-retirement readiness packet because this removes the
      path used by existing issue-intake users. Standing authorization covers
      closure only after every preceding gate is satisfied.
- [ ] Close issue intake in a single-purpose repository change.
- [ ] Verify the server path remains available and documented.

## 14. Final audit and definition of done

- [ ] Check every completion criterion in completion-plan section 13.
- [ ] Search every allowlisted repository for stale FC, disproof,
      experimental-kernel, model-consolidation-launch, and persistent-harness
      instructions.
- [ ] Confirm remaining mentions are historical context or explicit exclusions,
      not TODOs.
- [ ] Confirm current infrastructure and rollback documents contain current
      facts only.
- [ ] Confirm no unexplained open overhaul PR, active workflow, or local-only
      required change remains.
- [ ] Run final repository validation with no errors or linter warnings.
- [ ] Mark this runbook complete and summarize current operation and ordinary
      maintenance ownership.

Production launch restore `39b2e67f7583926a4f1d66b723b5d4cf4756dd32`
is live through deployed descendant
`27fe540135dfcc6c0e21fccf3ab0f9eff51d49d8` with durable intake. Full
completion is deliberately calendar-bound and occurs only when every
completion-plan criterion is actually satisfied.

## 15. Compact status table

Update this table in place; do not append a history beneath it.

| Phase | State | Current blocker |
| --- | --- | --- |
| 0. Rebaseline cleanup | Complete | — |
| 1. Disabled baseline | Complete | — |
| 2. Repository launch preparation | Complete | — |
| Credential boundary | Complete | — |
| 3. Final staging acceptance | Complete | — |
| Production launch readiness | Complete | — |
| 4. Launch | Complete; clean-break intake v2 and updated public guidance are live, and the bounded production submission reached an accepted result | — |
| 5. Four-week overlap | In progress; automatic publication, durable server intake, and server-primary entry live; calendar-bound; future cutoff variable installed | Keep issue intake open through at least `2026-09-30T06:57:10Z`; the conditional closure notice matures `2026-09-16T23:06:35Z`, and the canary automatic-release checkpoint is `2026-11-02T03:50:01.002Z` |
| 6. Historical completion | In progress: v1 is terminal; the finite non-v1 campaign has been added to scope | Drain 145 public and 562 private tasks, then freeze and drain the final issue-intake delta before removing temporary machinery again |
| 7. Remaining product completion | In progress | Open problems and editorial work are complete; final live release/replay presentation and issue closure retain their calendar, stability, adoption, and readiness gates |
| Final audit | Preparatory cleanup complete; final audit pending | Repeat the audit after all phases and confirm only explained launch and retirement work remains |
