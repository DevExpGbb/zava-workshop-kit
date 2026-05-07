# Manual mirror cheatsheet — when bootstrap-emu.sh isn't available

Use this when `bin/bootstrap-emu.sh` fails, when you need to recover a single repo without re-running the full script, or when you want to understand exactly what bootstrap-emu.sh does under the hood.

**Time budget:** ~10 minutes per repo. ~30 minutes total for the 3 core repos (template is "Use this template", not bootstrapped).

---

## Prerequisites

Same as `bootstrap-emu.sh`:
- `GH_TOKEN_SOURCE` — personal `github.com` PAT, `repo` (read) on `DevExpGbb`
- `GH_TOKEN_TARGET` — EMU PAT, `repo` + `workflow` + `admin:org` on the target org
- Both available as env vars in your shell

---

## The 4 commands per repo

```bash
# 1. Mirror clone from public github.com using source token
SRC=$GH_TOKEN_SOURCE
TGT=$GH_TOKEN_TARGET
SOURCE_ORG=DevExpGbb
TARGET_ORG=<customer>-platform
REPO=zava-agent-config       # or zava-storefront, poisoned-tracing-skill

git clone --mirror "https://x-access-token:$SRC@github.com/$SOURCE_ORG/$REPO.git" "$REPO.mirror"

# 2. Create empty internal repo in target EMU org using target token
GH_TOKEN=$TGT gh repo create "$TARGET_ORG/$REPO" --internal \
  --description "Mirrored from $SOURCE_ORG/$REPO for EMU workshop"

# 3. Push --mirror to the target (preserves all branches + tags + history)
cd "$REPO.mirror"
git push --mirror "https://x-access-token:$TGT@github.com/$TARGET_ORG/$REPO.git"
cd ..

# 4. Enable Actions on the target repo (mirror push doesn't enable them by default)
echo '{"enabled":true,"allowed_actions":"all"}' \
  | GH_TOKEN=$TGT gh api -X PUT "repos/$TARGET_ORG/$REPO/actions/permissions" --input -
```

Run the block above for each of: `zava-agent-config`, `zava-storefront`, `poisoned-tracing-skill`.

---

## Ref-rewrite (only needed if `apm install` will hit the marketplace)

Mirrored repos still reference `DevExpGbb/...` in their workflow YAML and `marketplace.json`. If attendees will run `apm install <target-org>/zava-agent-config@v5.0.1`, you must rewrite the source-org references inside each repo:

```bash
# Working clone (not mirror) for editing
GH_TOKEN=$TGT git clone "https://x-access-token:$TGT@github.com/$TARGET_ORG/$REPO.git"
cd "$REPO"

# Find + rewrite
hits=$(grep -rl "$SOURCE_ORG/" --include="*.yml" --include="*.yaml" --include="*.md" --include="*.json" . | grep -v "^./.git/")
echo "$hits" | xargs sed -i.bak "s|$SOURCE_ORG/|$TARGET_ORG/|g"
find . -name "*.bak" -delete

# Commit + push
git -c user.name="Bridge" -c user.email="bridge@example.com" \
  commit -am "chore: rewrite refs $SOURCE_ORG → $TARGET_ORG"
git push origin HEAD
cd ..
```

---

## Trigger release.yml on `zava-agent-config`

Mirror push brings the `v5.0.1` tag over but **suppresses workflow events** (this is GitHub's behavior for `--mirror` pushes). Re-push the tag explicitly to fire `release.yml`:

```bash
cd zava-agent-config
LATEST_TAG=$(GH_TOKEN=$SRC gh api "repos/$SOURCE_ORG/zava-agent-config/releases/latest" --jq .tag_name)
git push --force \
  "https://x-access-token:$TGT@github.com/$TARGET_ORG/zava-agent-config.git" \
  "refs/tags/$LATEST_TAG:refs/tags/$LATEST_TAG"
cd ..
```

Wait ~30 seconds, then verify:
```bash
GH_TOKEN=$TGT gh release view --repo "$TARGET_ORG/zava-agent-config" "$LATEST_TAG"
```

You should see 6 plugin tarballs + 6 sha256 files + `marketplace.json` as release assets.

---

## Org policy (`<target-org>/.github`)

```bash
GH_TOKEN=$TGT gh repo create "$TARGET_ORG/.github" --internal \
  --description "Org defaults for $TARGET_ORG" --add-readme
GH_TOKEN=$TGT git clone "https://x-access-token:$TGT@github.com/$TARGET_ORG/.github.git"
cd .github

# Template the policy (KIT_DIR is wherever you cloned zava-workshop-kit)
sed "s|YOUR_ORG|$TARGET_ORG|g" "$KIT_DIR/templates/apm-policy.yml" > apm-policy.yml

git add apm-policy.yml
git -c user.name="Bridge" -c user.email="bridge@example.com" \
  commit -m "chore: org-level apm-policy.yml"
git push origin HEAD
cd ..
```

---

## One-time admin steps (no script — UI or API only)

These cannot be automated by a third-party script; they require org-owner UI access:

```bash
# Set COPILOT_GITHUB_TOKEN as an org secret
GH_TOKEN=$TGT gh secret set COPILOT_GITHUB_TOKEN \
  --org "$TARGET_ORG" --body "$EMU_ISSUED_PAT"

# Verify
GH_TOKEN=$TGT gh secret list --org "$TARGET_ORG"
```

---

## Verification — are we ready for the workshop?

```bash
# 1. All 4 repos exist and are internal
GH_TOKEN=$TGT gh repo list "$TARGET_ORG" --visibility=internal --json name,visibility

# 2. zava-agent-config has the release published
GH_TOKEN=$TGT gh release list --repo "$TARGET_ORG/zava-agent-config"

# 3. COPILOT_GITHUB_TOKEN is set at org level
GH_TOKEN=$TGT gh secret list --org "$TARGET_ORG" | grep COPILOT_GITHUB_TOKEN

# 4. Smoke test
GH_TOKEN=$TGT ./bin/smoke.sh --org="$TARGET_ORG"
```

If all 4 pass, you're ready for the workshop. If `release.yml` step (#2) failed, see [live-workshop-runbook.md § Mode 2](live-workshop-runbook.md#mode-2--repos-mirrored-but-releaseyml-never-fired-no-marketplace-assets) — you can still run 95% of the workshop using `apm install ./local-path` instead of marketplace install.
