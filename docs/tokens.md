# Tokens — what to create and why

The workshop needs **two** Personal Access Tokens, both stored as **org-level secrets**.

## `COPILOT_GITHUB_TOKEN`

The `gh aw` workflows (PR Review Panel, Triage Panel, etc.) invoke Copilot agents on your behalf. They need a token that can:

- Read code and PR metadata
- Post review comments and create branches
- Trigger workflows and read workflow status

### Recipe

1. Go to **Settings → Developer settings → Personal access tokens → Fine-grained tokens** under the user account that should "own" the workshop bot identity (often the org owner).
2. Click **Generate new token**.
3. Configure:
   - **Token name:** `zava-workshop-copilot`
   - **Expiration:** 90 days (rotate for production workshops)
   - **Resource owner:** *YOUR_ORG*
   - **Repository access:** All repositories
   - **Permissions → Repository:**
     - `Contents`: Read+Write
     - `Issues`: Read+Write
     - `Pull requests`: Read+Write
     - `Workflows`: Read+Write
     - `Actions`: Read
     - `Metadata`: Read (auto)
4. Generate, copy the value.
5. Set as org secret: `gh secret set COPILOT_GITHUB_TOKEN --org YOUR_ORG --visibility=all`

## `GH_AW_PLUGINS_TOKEN`

The `gh aw` action pulls plugins (e.g. `microsoft/apm`) from the GitHub Container Registry. It needs a token that can read packages.

### Recipe

1. Same path: **Settings → Developer settings → Personal access tokens → Fine-grained tokens**.
2. Configure:
   - **Token name:** `zava-workshop-plugins`
   - **Expiration:** 1 year (rotate annually)
   - **Resource owner:** your personal account (the token reads public packages, no org scope needed)
   - **Repository access:** Public repositories (read-only)
   - **Permissions → Account:**
     - `Packages`: Read
3. Generate, copy.
4. Set as org secret: `gh secret set GH_AW_PLUGINS_TOKEN --org YOUR_ORG --visibility=all`

## Verifying

```bash
gh secret list --org YOUR_ORG
# Should show both with VISIBILITY=all
```

## Rotation

Both secrets can be rotated zero-downtime: generate new token, set the secret again with same name, delete the old token. In-flight workflow runs continue with the value they captured at start.

## Why fine-grained over classic PATs?

Classic PATs grant org-wide repo access if the user has it. Fine-grained PATs scope to specific repos, which matches the principle-of-least-privilege story we tell during the workshop's Governance segment.
