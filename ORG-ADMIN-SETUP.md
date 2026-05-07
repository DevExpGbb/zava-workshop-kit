# Org Admin Setup — Zava Workshop Kit

> **For:** the org owner (one person) deploying the workshop into a fresh org.
> **Time:** 15–25 minutes end-to-end.
> **Prereq mindset:** if you've ever run `gh repo create` and `gh secret set`, you have everything you need.

This runbook gets you from **empty org** to **working workshop where trainees can fork the template and ship a skill**.

If `bin/preflight.sh` and `bin/bootstrap.sh` succeed without you reading further — great. This doc is the manual fallback and the explanation of what those scripts do.

---

## Step 1 — Verify org prerequisites

Your org must be one of:
- **GitHub Enterprise Cloud** (recommended for production workshops)
- **GitHub Team / Business** (works; some advanced rulesets unavailable)
- **GitHub Free org** (works for evaluation; no rulesets)

In **Settings → Actions → General**:
- ☑ Allow all actions and reusable workflows
- ☑ Allow GitHub Actions to create and approve pull requests
- ☑ Workflow permissions: read+write

In **Settings → Packages**:
- ☑ Inherit access from source repository (default is fine)

In **Settings → Copilot**:
- A **Copilot Business or Enterprise** plan must be active. The `gh aw` workflows in this kit use `engine: copilot`. See [`docs/copilot-plan.md`](docs/copilot-plan.md) if unsure.

---

## Step 2 — Create two Personal Access Tokens

The org needs two tokens. Both are created under **a single user account** (typically you, the admin) and stored as **org-level secrets**. See [`docs/tokens.md`](docs/tokens.md) for screenshots.

### `COPILOT_GITHUB_TOKEN`
- **Type:** Fine-grained PAT
- **Resource owner:** your org
- **Repository access:** all repositories
- **Permissions:** `Contents: Read+Write`, `Issues: Read+Write`, `Pull requests: Read+Write`, `Workflows: Read+Write`
- **Used by:** `gh aw` workflows to invoke Copilot agents

### `GH_AW_PLUGINS_TOKEN`
- **Type:** Fine-grained PAT
- **Resource owner:** your account (read-only)
- **Permissions:** `Packages: Read`
- **Used by:** the `gh aw` action to pull plugins from the GitHub Container Registry

---

## Step 3 — Set the org secrets

```bash
gh secret set COPILOT_GITHUB_TOKEN --org YOUR_ORG --visibility=all
gh secret set GH_AW_PLUGINS_TOKEN  --org YOUR_ORG --visibility=all
```

Or skip this step and let `bin/bootstrap.sh` prompt you interactively.

---

## Step 4 — Apply rulesets

Two rulesets ship in `templates/`. Both are recommended; the second is required only if you want to demonstrate the D2 Governance demo.

### `tag-immutability` (mandatory)
Prevents tag overwrites. Without this, marketplace pinning (`#v5.0.1`) is unsafe.

```bash
gh api orgs/YOUR_ORG/rulesets --method POST \
  --input templates/tag-immutability.ruleset.json
```

### `apm-audit-required` (recommended)
Requires the `apm-audit` status check on PRs that modify `apm.yml` in any repo pinning `zava-agent-config`. Demonstrated in D2 Governance.

```bash
gh api orgs/YOUR_ORG/rulesets --method POST \
  --input templates/apm-audit-required.ruleset.json
```

---

## Step 5 — Run the bootstrap

```bash
./bin/bootstrap.sh --org=YOUR_ORG
```

What this does (in order):

1. Forks `DevExpGbb/zava-agent-config` → `YOUR_ORG/zava-agent-config`
2. Forks `DevExpGbb/zava-storefront` → `YOUR_ORG/zava-storefront`
3. Forks `DevExpGbb/poisoned-tracing-skill` → `YOUR_ORG/poisoned-tracing-skill`
4. (Skipped: workshop-template — trainees use **"Use this template"** directly against `DevExpGbb/zava-skills-workshop-template`)
5. Rewrites `apm.yml` and gh-aw workflow refs in your forks: `DevExpGbb/` → `YOUR_ORG/`
6. Pushes the rewrites as a single commit on `main`
7. Creates the org `.github` repo (if missing) and adds `apm-policy.yml`
8. Triggers the `release.yml` workflow on `YOUR_ORG/zava-agent-config` to publish `v5.0.1` in your org's GitHub Releases

**The script is idempotent.** Re-run it safely; it skips work that's already done.

---

## Step 6 — Smoke test

```bash
./bin/smoke.sh --org=YOUR_ORG
```

This:
1. Opens a tiny no-op PR against `YOUR_ORG/zava-storefront`
2. Labels it `panel-review`
3. Polls until the `pr-review-panel` workflow run completes
4. Asserts green
5. Cleans up the PR + branch

If it exits with `OK ✅`, your workshop is live.

---

## Step 7 — (Optional) Configure Azure SRE Agent

Only needed if you want to demo D5 Meeting-to-code's final leg (Azure SRE Agent → remediation PR). See [`docs/azure-sre.md`](docs/azure-sre.md). Skip if you're cutting D5's SRE leg — the rest of the workshop works without it.

---

## You're done

Hand trainees this URL: **https://github.com/DevExpGbb/zava-skills-workshop-template** and tell them:

> "Click **Use this template** at the top right. Create the new repo in our org. Then follow that repo's README from step 1."

That's the entire trainee onboarding. They'll need their own GitHub account to be a member of your org, but no special permissions beyond `Write` on their own forked repos.

---

## Troubleshooting

See [`docs/troubleshooting.md`](docs/troubleshooting.md). The 5 most common issues:

1. **`apm install` 404s on a plugin:** apm.yml refs not rewritten. Re-run `bin/bootstrap.sh`.
2. **`gh aw` workflow fails with "no token":** `COPILOT_GITHUB_TOKEN` org secret missing or wrong scopes.
3. **`pr-review-panel.yml` skipped:** label name mismatch — must be exactly `panel-review`.
4. **Copilot rate limit during smoke:** your Copilot plan doesn't include enough seats — see `docs/copilot-plan.md`.
5. **Rulesets API 403:** your account isn't an org owner.
