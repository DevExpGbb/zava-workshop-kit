# Tokens — what to create and why

The workshop needs **two** Personal Access Tokens, both stored as **org-level secrets**.

## `COPILOT_GITHUB_TOKEN`

`gh aw` workflows that run with `engine: copilot` need this token to authenticate the Copilot CLI for inference. Per the [upstream `gh aw` auth reference](https://github.github.com/gh-aw/reference/auth/#copilot_github_token), it must be a **fine-grained PAT** with exactly one permission. GitHub Apps, OAuth tokens, and classic PATs are not supported for this secret.

The token does **not** need repo, workflow, or any other scope — `GITHUB_TOKEN` already covers everything else the compiled workflow does. The only thing this PAT authenticates is the Copilot inference call.

### Recipe

1. Open the pre-filled link (it sets the name, description, and permission for you):

   <https://github.com/settings/personal-access-tokens/new?name=COPILOT_GITHUB_TOKEN&description=GitHub+Agentic+Workflows+-+Copilot+engine+authentication&user_copilot_requests=read>

2. Verify before generating:
   - **Resource owner: your user account** (NOT an org — `Copilot Requests` is an account-level permission and is hidden on org-owned fine-grained PATs).
   - **Repository access:** Public repositories (read-only) is fine — this PAT does not touch repos.
   - **Permissions → Account → Copilot Requests: Read** — and nothing else.
   - **Expiration:** 90 days (rotate for production workshops).
3. Generate, copy the value.
4. The token owner's account **must have an active Copilot Business/Enterprise seat**, otherwise inference fails with `403 Resource not accessible by personal access token`.
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
