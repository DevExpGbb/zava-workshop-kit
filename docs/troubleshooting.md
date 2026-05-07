# Troubleshooting

## Bootstrap failures

### `gh repo fork` fails with 404 or "not found"
**Cause:** Source repo is private or your `gh` auth lacks the right scope.
**Fix:** All `DevExpGbb/zava-*` repos are public. Re-run `gh auth login` and grant `repo` scope.

### `gh repo fork` fails with "Resource not accessible by integration"
**Cause:** You're acting as a GitHub App / fine-grained PAT without `Administration: Write` on the org.
**Fix:** Run as your user identity with `gh auth login` (web-based), not via a token.

### Sed rewrite leaves stale refs
**Cause:** A file extension not in the rewrite glob (`yml,yaml,md,json`). Most common: shell scripts.
**Fix:** Manually grep + fix: `grep -r "DevExpGbb/" YOUR_ORG_FORK/`. File a kit issue if it's a recurring pattern.

### Tag push rejected with "tag already exists"
**Cause:** Your fork already has `v5.0.1` from inheriting tags.
**Fix:** This is fine — bootstrap.sh detects this and skips. If you got the error mid-script, just re-run bootstrap.

### Release workflow doesn't fire
**Cause:** `workflow_dispatch` permission missing on the release.yml in your fork.
**Fix:** Open `YOUR_ORG/zava-agent-config` → Actions → Run "release" workflow manually with the tag input.

## `apm install` failures

### "404: plugin not found"
**Cause:** apm.yml still references `DevExpGbb/` instead of `YOUR_ORG/` (rewrite missed) OR your fork hasn't published the marketplace release yet.
**Fix:**
1. `grep -r "DevExpGbb/" .` in your storefront fork — should be empty
2. Check `gh release list --repo YOUR_ORG/zava-agent-config` shows v5.0.1
3. Re-run `bin/bootstrap.sh --org=YOUR_ORG`

### "policy violation: source not allowed"
**Cause:** `apm-policy.yml` in `YOUR_ORG/.github` still has `YOUR_ORG` placeholder (literal).
**Fix:** Edit `YOUR_ORG/.github/apm-policy.yml`, replace `YOUR_ORG` literal with your actual org slug, commit.

### "supply chain attack detected" / lockfile content hash mismatch
**Cause:** Each org publishes its own release tarball when triggering `release.yml` on a tag. Even at the same version (e.g. `v5.0.1`), `YOUR_ORG/zava-agent-config` and `DevExpGbb/zava-agent-config` produce different SHA256 hashes. The lockfile inherited from the source org will fail audit against your fork's content.
**Fix:** Bootstrap.sh now regenerates `apm.lock.yaml` automatically post-rewrite if the `apm` CLI is on PATH. If you ran an older bootstrap or apm wasn't installed:
```bash
cd YOUR_FORK_OF_zava-storefront
apm install --update
git commit -am "chore(apm): regenerate lockfile against YOUR_ORG plugins"
git push
```
Requires `apm` CLI: `brew install microsoft/apm/apm` or see [apm.dev](https://apm.dev).

## `gh aw` / workflow failures

### Workflow runs immediately fail with "no token"
**Cause:** Org secret `COPILOT_GITHUB_TOKEN` or `GH_AW_PLUGINS_TOKEN` missing.
**Fix:** `gh secret list --org YOUR_ORG` — should show both. Run `bin/preflight.sh` to verify.

### Workflow runs but Copilot returns "rate limited"
**Cause:** Copilot Business plan seat exhausted, or token user doesn't have a seat.
**Fix:** Verify in **Settings → Copilot → Access** that the bot user has an active seat. See `docs/copilot-plan.md`.

### `pr-review-panel.yml` skipped on PR
**Cause:** Label name mismatch. Workflow listens for **exactly** `panel-review`.
**Fix:** Check the label exists in the repo (it's auto-created on first use). Spelling: `panel-review`, not `pr-review` or `review`.

### `triage-panel.yml` doesn't fire on issue
**Cause:** Same label mismatch. Triage listens for `triage`.
**Fix:** Add the literal label `triage`.

## Smoke test failures

### `smoke.sh` says "no workflow run appeared in 600s"
**Cause:** PR didn't get the label, or workflow file isn't on `main`.
**Fix:**
1. Check the PR has the `panel-review` label
2. Check `YOUR_ORG/zava-storefront/.github/workflows/pr-review-panel.lock.yml` exists on main
3. Check **Actions** tab is enabled in repo settings

### `smoke.sh` cleanup leaves a branch
**Cause:** Network blip during PR close.
**Fix:** Manually: `git push origin --delete smoke/kit-<timestamp>` and `gh pr close <N>`.

## Ruleset failures

### `gh api orgs/YOUR_ORG/rulesets --method POST` returns 403
**Cause:** Your account isn't an org owner.
**Fix:** Have an org owner run the ruleset commands, or transfer org ownership before running.

### `gh api orgs/YOUR_ORG/rulesets --method POST` returns 422
**Cause:** Ruleset name already exists in the org.
**Fix:** This is fine — re-application is a no-op for our two rulesets. To force-update: delete first via the org Settings UI, then re-apply.

## Still stuck?

File an issue in this kit's repo with:
- Which step (preflight / bootstrap / smoke / teardown / manual)
- The exact command + flags
- Output of `gh --version` and `gh auth status`
- The error message verbatim
