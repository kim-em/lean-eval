# CI secrets and access control for `leanprover/lean-eval`

This document is the source of truth for every CI credential and branch-
protection setting the repository depends on. It is written so that, on a
fresh clone or a brand-new repo, you can reconstruct the entire CI auth
posture from this file alone — no UI screenshots, no tribal knowledge.

## Audit checklist

| Item | Type | Stored as | Used by |
| --- | --- | --- | --- |
| `lean-eval-bot` | GitHub App (owner: `kim-em`) | `LEAN_EVAL_BOT_APP_ID`, `LEAN_EVAL_BOT_PRIVATE_KEY` | `submission.yml` |
| `lean-eval-regenerator` | GitHub App (owner: `kim-em`) | `LEAN_EVAL_REGENERATOR_APP_ID`, `LEAN_EVAL_REGENERATOR_PRIVATE_KEY` | `regenerate-main.yml` |
| `LEADERBOARD_WRITE_TOKEN` | Fine-grained PAT | `LEADERBOARD_WRITE_TOKEN` (in both `leanprover/lean-eval` and `leanprover/lean-eval-leaderboard`) | `submission.yml`, `notify-leaderboard.yml` (this repo); `bump-benchmark-snapshot.yml` (leaderboard) |
| Ruleset `main protection` | Repository Ruleset | (config in this repo, applied via API) | branch protection on `main` |

To check the live state at any time:

```bash
gh secret list -R leanprover/lean-eval
gh api /repos/leanprover/lean-eval/rules/branches/main \
    --jq '[.[].type]'
```

## GitHub App: `lean-eval-bot`

Used by [`.github/workflows/submission.yml`](../.github/workflows/submission.yml)
to mint installation tokens that fetch submission source from contributor
repositories (which may be private).

### App settings

- Owner account: `kim-em` (User account).
- Webhook: deactivated.
- Repository permissions:
  - `Contents: Read`
- Where can this GitHub App be installed: **Any account**. Contributors
  install it on their own submission repos so the workflow can clone them.

### Repository secrets (in `leanprover/lean-eval`)

- `LEAN_EVAL_BOT_APP_ID` — the App ID number.
- `LEAN_EVAL_BOT_PRIVATE_KEY` — the full PEM contents of a private key
  generated for the app.

### Where used

[`.github/workflows/submission.yml`](../.github/workflows/submission.yml),
in the `Mint lean-eval-bot installation token` step, via
`actions/create-github-app-token@v1`. The minted token is then used to
fetch the contributor's submission source.

The issue template
[`.github/ISSUE_TEMPLATE/submit.yml`](../.github/ISSUE_TEMPLATE/submit.yml)
instructs contributors to install this app on their submission repo as
part of the submission workflow.

### Reconstruction from scratch

1. As the desired app owner, visit <https://github.com/settings/apps/new>.
2. Fill in:
   - Name: `lean-eval-bot`
   - Homepage URL: `https://github.com/leanprover/lean-eval`
   - Webhook → Active: unchecked
   - Repository permissions → Contents: Read
   - Where can this GitHub App be installed: **Any account**
3. Save → record the App ID.
4. Generate a private key, download the `.pem`.
5. Install the app on `leanprover/lean-eval` (so it has an installation
   the workflow can mint tokens against).
6. Set the secrets:
   ```bash
   gh secret set LEAN_EVAL_BOT_APP_ID -R leanprover/lean-eval --body <APP_ID>
   gh secret set LEAN_EVAL_BOT_PRIVATE_KEY -R leanprover/lean-eval < path/to/key.pem
   ```

## GitHub App: `lean-eval-regenerator`

Used by [`.github/workflows/regenerate-main.yml`](../.github/workflows/regenerate-main.yml)
to push regenerated `generated/` workspaces directly to `main`, bypassing
branch protection.

### App settings

- Owner account: `kim-em` (User account).
- Webhook: deactivated.
- Repository permissions:
  - `Contents: Read and write`
- Where can this GitHub App be installed: **Any account**. (Required so
  the org can install it; the only intended installation is on
  `leanprover/lean-eval` itself.)
- Installed on: `leanprover/lean-eval` only (single-repo installation).

### Repository secrets (in `leanprover/lean-eval`)

- `LEAN_EVAL_REGENERATOR_APP_ID` — the App ID number.
- `LEAN_EVAL_REGENERATOR_PRIVATE_KEY` — the full PEM contents of a private
  key generated for the app.

### Where used

[`.github/workflows/regenerate-main.yml`](../.github/workflows/regenerate-main.yml),
in the `Mint lean-eval-regenerator installation token` step, via
`actions/create-github-app-token@v1`. The token is used both for
`actions/checkout` (so subsequent `git push` carries the same auth) and
for the explicit push step that lands the regenerated workspaces on
`main`.

### Why an app and not `GITHUB_TOKEN`

`GITHUB_TOKEN`-authored pushes cannot bypass branch protection (no actor
can put `github-actions[bot]` itself in the bypass list at workflow
granularity). A dedicated app's principal can be in the bypass list (see
the Ruleset section below); the bypass is then narrow because only this
workflow has the app's secrets.

### Reconstruction from scratch

There is a helper script [`scripts/create_regenerator_app.py`](../scripts/create_regenerator_app.py)
that automates most of this via the GitHub App Manifest flow. Manual
fallback steps:

1. As the desired app owner, visit <https://github.com/settings/apps/new>.
2. Fill in:
   - Name: `lean-eval-regenerator`
   - Homepage URL: `https://github.com/leanprover/lean-eval`
   - Webhook → Active: unchecked
   - Repository permissions → Contents: Read and write (everything else
     stays "No access")
   - Where can this GitHub App be installed: **Any account**
3. Save → record the App ID.
4. Generate a private key, download the `.pem`.
5. Install the app on `leanprover/lean-eval` only (Org owner must do this
   if the repo is in an org with restricted third-party app access).
6. Set the secrets:
   ```bash
   gh secret set LEAN_EVAL_REGENERATOR_APP_ID -R leanprover/lean-eval --body <APP_ID>
   gh secret set LEAN_EVAL_REGENERATOR_PRIVATE_KEY -R leanprover/lean-eval < path/to/key.pem
   ```
7. Add the App ID to the `main` ruleset's bypass list (see Ruleset
   section below).

## PAT: `LEADERBOARD_WRITE_TOKEN`

Fine-grained Personal Access Token used by three workflows to drive the
leaderboard repository (<https://github.com/leanprover/lean-eval-leaderboard>):

- [`.github/workflows/submission.yml`](../.github/workflows/submission.yml)
  in this repo — pushes a `record:` commit to leaderboard `main` when a
  submission succeeds.
- [`.github/workflows/notify-leaderboard.yml`](../.github/workflows/notify-leaderboard.yml)
  in this repo — fires a `repository_dispatch` event into the leaderboard
  whenever a problem-affecting change lands on this repo's `main`,
  signalling that the snapshot pin should advance.
- `.github/workflows/bump-benchmark-snapshot.yml` in the leaderboard
  repo — listens for that dispatch (and `workflow_dispatch`),
  regenerates `benchmark-snapshot/` from the latest `lean-eval` main,
  runs `lake build` as the gate, and direct-pushes the bump to
  leaderboard `main`. The deploy workflow then republishes the site.

The token must be a fine-grained PAT issued under your personal account
(not the org), with the leaderboard repo selected and `Contents: Read
and write`. That permission is sufficient both for direct pushes (the
PAT owner is a leaderboard admin and so bypasses branch protection) and
for `repository_dispatch` (per
<https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event>).

### Repository secrets

The same token value is stored in **two** places — once per repo that
needs to use it:

- `LEADERBOARD_WRITE_TOKEN` in `leanprover/lean-eval` (used by
  `submission.yml` and `notify-leaderboard.yml`).
- `LEADERBOARD_WRITE_TOKEN` in `leanprover/lean-eval-leaderboard` (used
  by `bump-benchmark-snapshot.yml`).

When rotating the PAT, update **both** secrets together. Forgetting one
causes silent half-failures: e.g., dispatch fires but the bump's
push step rejects, or vice versa.

### Reconstruction from scratch

1. Open <https://github.com/settings/personal-access-tokens/new>.
2. Resource owner: **leanprover** (requires org owner approval —
   another org owner must approve the request, you cannot self-approve
   even if you are an owner; see the
   [`personal-access-token-requests` page](https://github.com/organizations/leanprover/settings/personal-access-token-requests)).
3. Repository access: **Only select repositories** →
   `leanprover/lean-eval-leaderboard`.
4. Repository permissions: **Contents: Read and write**.
5. Save the token, then write it to both repos:
   ```bash
   # lean-eval is the side that fires the dispatch and pushes records.
   gh secret set LEADERBOARD_WRITE_TOKEN -R leanprover/lean-eval --body <TOKEN>
   # The leaderboard side checks itself out with this token so its
   # snapshot-bump push back to its own main bypasses branch protection.
   gh secret set LEADERBOARD_WRITE_TOKEN -R leanprover/lean-eval-leaderboard --body <TOKEN>
   ```

## Branch protection on `main` (Repository Ruleset)

`main` is protected by a Repository Ruleset (not classic branch
protection). The `lean-eval-regenerator` app is on the bypass list so its
workflow can push directly; everyone and everything else must go through
a PR with a passing `verify` check.

### Live state inspection

```bash
gh api /repos/leanprover/lean-eval/rules/branches/main \
    --jq '.[] | {type, ruleset_id}'
gh api /repos/leanprover/lean-eval/rulesets \
    --jq '.[] | {id, name, target, enforcement}'
gh api "/repos/leanprover/lean-eval/rulesets/<ID>" \
    --jq '{name, bypass_actors}'
```

### Ruleset payload (canonical)

The `<REGEN_APP_ID>` placeholder is the `lean-eval-regenerator` App ID.
`integration_id: 15368` pins the `verify` status check to the GitHub
Actions app (id 15368), so a hostile third-party app can't satisfy it
with a bogus check of the same name.

```json
{
  "name": "main protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false } },
    { "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [ { "context": "verify", "integration_id": 15368 } ] } }
  ],
  "bypass_actors": [
    { "actor_id": <REGEN_APP_ID>, "actor_type": "Integration", "bypass_mode": "always" }
  ]
}
```

### Reconstruction from scratch

1. Make sure the `lean-eval-regenerator` app exists, is installed on the
   repo, and you know its App ID.
2. Save the payload above to `/tmp/main-ruleset.json`, substituting the
   App ID.
3. Apply:
   ```bash
   gh api -X POST /repos/leanprover/lean-eval/rulesets \
       --input /tmp/main-ruleset.json
   ```
4. If migrating from classic branch protection, delete the classic
   protection only after the ruleset is confirmed active:
   ```bash
   gh api /repos/leanprover/lean-eval/rules/branches/main \
       --jq '[.[].type]'   # expect 4 rules
   gh api -X DELETE /repos/leanprover/lean-eval/branches/main/protection
   ```

### Acceptable consequences of the bypass

- `regenerate-main.yml`'s pushes to `main` will *not* re-trigger
  `regenerate-main.yml` itself: that workflow's `paths:` filter only
  fires on source changes (`LeanEval/**`, `EvalTools/**`,
  `manifests/problems.toml`, `scripts/generate_projects.py`,
  `lakefile.toml`, `lean-toolchain`), and the bot only writes under
  `generated/`. The bypass doesn't change this; the `paths:` filter
  is what prevents the loop.

  Other workflows on `main` push events *do* run on regenerator
  commits — most notably `ci.yml`'s `verify` job, which has no
  `paths:` filter. That is intentional: it exercises the regenerated
  workspace. Per-step gating is the regenerator's responsibility when
  a check is genuinely PR-only (see the `pull_request`-gated
  Submission Policy Diff Check in `ci.yml`).

  The regen workflow itself runs `python scripts/generate_projects.py`
  before pushing, so the artifact landing on `main` is already vetted
  against the source.
- Anyone who can land a PR that modifies `regenerate-main.yml` to push
  arbitrary content to `main` could, after merge, exfiltrate that
  capability. This is the same trust boundary as merging any PR.
