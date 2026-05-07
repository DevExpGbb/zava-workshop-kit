# EMU Setup — bridge-engineer guide

This is the **EMU (Enterprise Managed Users)** deployment path. Use this if you're standing the workshop up inside a GitHub Enterprise Cloud org with **EMU enabled** (typical for regulated banks, healthcare, and large enterprises).

If your target org is a regular `github.com` org (free, Team, or Enterprise without EMU), use [`bin/bootstrap.sh`](../bin/bootstrap.sh) instead.

---

## What's different about EMU

EMU enterprises live on `github.com` but are **identity-isolated**:

- EMU users have suffixed handles (e.g. `daniel-meppiel_lloyds`)
- EMU users **cannot** see public `github.com` repos — `gh repo fork DevExpGbb/...` is impossible
- EMU orgs **cannot** have `public` visibility — only `internal` (visible across the enterprise) or `private`
- EMU runners may have a restricted **GitHub Actions allowlist**; `actions/checkout@v4` and other GitHub-owned actions must be on it

The fix is the **bridge engineer model**: one engineer holds **two PATs** on the same `github.com` host — a personal/source identity that can read `DevExpGbb`, and an EMU identity that can write to the target org. The bootstrap mirror-clones with the source token and `git push --mirror`s with the target token.

---

## Prerequisites

### Two PATs on the bridge machine

| Token | Identity | Required scopes | Used for |
|---|---|---|---|
| `GH_TOKEN_SOURCE` | Personal `github.com` (e.g. `danielmeppiel`) | `repo` (read) | Mirror-cloning `DevExpGbb/*` |
| `GH_TOKEN_TARGET` | EMU identity (e.g. `daniel-meppiel_lloyds`) | `repo`, `workflow`, `admin:org`, `delete_repo` | Creating, pushing, configuring the EMU org |

Generate each one in its own browser session (or incognito), since both live on `github.com` but require different logins.

### Enterprise Actions policy

Your enterprise admin must allow at least the following GitHub-owned actions (typical defaults — confirm with your platform team before booking the workshop):

- `actions/checkout`
- `actions/setup-node`
- `actions/upload-artifact`
- `actions/github-script`

If your enterprise uses `selected_actions` mode, the bootstrap's call to enable repo-level Actions will succeed but workflows will fail at runtime. Either widen the allowlist temporarily or add specific actions for the workshop window.

### Network egress

The bridge machine needs egress to `github.com` (it's the same host for both source and target — only the auth token changes per call).

---

## Run

```bash
export GH_TOKEN_SOURCE=ghp_personal_xxx
export GH_TOKEN_TARGET=ghp_emu_xxx

# Always dry-run first
./bin/bootstrap-emu.sh --target-org=YOUR_EMU_ORG --dry-run

# Real run (defaults to --visibility=internal)
./bin/bootstrap-emu.sh --target-org=YOUR_EMU_ORG

# After bootstrap, smoke-test (requires GH_TOKEN scoped to target)
GH_TOKEN=$GH_TOKEN_TARGET ./bin/smoke.sh --org=YOUR_EMU_ORG
```

### Visibility

`--visibility=internal` (default) makes the workshop repos visible to all EMU enterprise members — best for shared workshop content. Use `--visibility=private` for stricter isolation (only org members + explicit collaborators).

### Tear down

```bash
GH_TOKEN_TARGET=$GH_TOKEN_TARGET ./bin/teardown-emu.sh --target-org=YOUR_EMU_ORG --yes
```

---

## EMU-specific gotchas

1. **Mirror push suppresses workflow events.** `git push --mirror` brings tags over but does NOT fire `release.yml`. The bootstrap re-pushes the latest tag explicitly to trigger publication. If `release.yml` doesn't fire within ~30s of bootstrap completing, push the tag manually:
   ```bash
   git push --force "https://x-access-token:$GH_TOKEN_TARGET@github.com/$TARGET_ORG/zava-agent-config.git" \
     "refs/tags/v5.0.1:refs/tags/v5.0.1"
   ```

2. **Marketplace.json contains `https://github.com/DevExpGbb/...` raw URLs.** The bootstrap rewrites `DevExpGbb/` → `$TARGET_ORG/` (org slug only — the host stays `github.com` for both EMU and public). Verify after bootstrap by `gh api repos/$TARGET_ORG/zava-agent-config/contents/marketplace.json`.

3. **`COPILOT_GITHUB_TOKEN` must be EMU-issued.** A personal `github.com` PAT will not authenticate as the EMU service identity. The org admin must mint this on an EMU member account with `repo` + `workflow` scopes.

4. **Actions policy is enterprise-level, not org-level.** The bootstrap's `actions/permissions` PUT only enables Actions at the **repo** level; the enterprise-level allowlist is unchanged. Confirm with your platform team before the workshop.

5. **`teardown-emu.sh` requires `delete_repo` scope** on `GH_TOKEN_TARGET`. Add it via:
   ```bash
   gh auth refresh -h github.com -s delete_repo  # if using gh auth
   # or regenerate the PAT with delete_repo selected
   ```

---

## Verification status

This script is **structurally tested** (shellcheck clean, dry-run validates flow) but has **not** been end-to-end verified against a real EMU enterprise (the author does not have EMU access). The public-org [`bootstrap.sh`](../bin/bootstrap.sh) is fully E2E-verified and shares 80% of the post-clone logic. Report any issues at [DevExpGbb/zava-workshop-kit/issues](https://github.com/DevExpGbb/zava-workshop-kit/issues).
