#!/usr/bin/env bash
# bootstrap-emu.sh — deploy zava-* into a GitHub Enterprise Cloud EMU org
# (Enterprise Managed Users — same github.com host, identity-isolated).
#
# Bridge-engineer model: this script runs on a machine with TWO github.com
# identities available as PATs — a personal/source identity that can read
# DevExpGbb (public repos), and an EMU identity that can write to the target
# EMU org. EMU users cannot fork or read public repos directly, so we mirror
# clone with the source token and push --mirror with the target token.
#
# Usage:
#   GH_TOKEN_SOURCE=ghp_personal GH_TOKEN_TARGET=ghp_emu \
#     ./bin/bootstrap-emu.sh --target-org=acme-emu [--visibility=internal]
#
# Required env:
#   GH_TOKEN_SOURCE   PAT on personal/source github.com identity (read on $SOURCE_ORG)
#   GH_TOKEN_TARGET   PAT on EMU identity (admin on $TARGET_ORG, repo+workflow scope)
#
# See docs/emu-setup.md for token scopes and EMU-specific gotchas.
set -euo pipefail

TARGET_ORG=""
SOURCE_ORG="DevExpGbb"
VISIBILITY="internal"   # internal | private (no public on EMU)
SKIP_TEMPLATE=true
DRY_RUN=false
FORCE=false

for a in "$@"; do
  case "$a" in
    --target-org=*) TARGET_ORG="${a#--target-org=}" ;;
    --source-org=*) SOURCE_ORG="${a#--source-org=}" ;;
    --visibility=*) VISIBILITY="${a#--visibility=}" ;;
    --include-template) SKIP_TEMPLATE=false ;;
    --dry-run) DRY_RUN=true ;;
    --force) FORCE=true ;;
    *) echo "unknown arg: $a"; exit 2 ;;
  esac
done

usage() {
  cat <<EOF >&2
usage: $0 --target-org=<emu-org> [--source-org=DevExpGbb] [--visibility=internal|private] [--dry-run] [--force]

Required env vars:
  GH_TOKEN_SOURCE   PAT on personal github.com identity, read access to \$SOURCE_ORG
  GH_TOKEN_TARGET   PAT on EMU identity, admin on \$TARGET_ORG (scopes: repo, workflow, admin:org)

EMU constraint: --visibility cannot be 'public' (EMU orgs only allow internal/private).
EOF
  exit 2
}

[[ -z "$TARGET_ORG" ]] && usage
[[ "$VISIBILITY" == "public" ]] && { echo "❌ --visibility=public is not allowed on EMU orgs (use 'internal' or 'private')"; exit 2; }
[[ "$VISIBILITY" != "internal" && "$VISIBILITY" != "private" ]] && { echo "❌ --visibility must be 'internal' or 'private'"; exit 2; }
[[ -z "${GH_TOKEN_SOURCE:-}" ]] && { echo "❌ GH_TOKEN_SOURCE not set"; usage; }
[[ -z "${GH_TOKEN_TARGET:-}" ]] && { echo "❌ GH_TOKEN_TARGET not set"; usage; }

if [[ "$TARGET_ORG" == "$SOURCE_ORG" ]]; then
  echo "❌ Refusing to bootstrap into source org '$SOURCE_ORG'."
  exit 2
fi

if $DRY_RUN; then
  echo "🔍 DRY-RUN MODE — no GitHub state will be modified."
  echo
fi

run() {
  if $DRY_RUN; then
    echo "  [DRYRUN] $*"
  else
    "$@"
  fi
}

# Capture KIT_DIR before any cd — BASH_SOURCE[0] may be relative.
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WORK="${WORK:-/tmp/zava-bootstrap-emu-$TARGET_ORG}"
mkdir -p "$WORK" && cd "$WORK"

REPOS=(zava-agent-config zava-storefront poisoned-tracing-skill)
$SKIP_TEMPLATE || REPOS+=(zava-skills-workshop-template)

echo "=== bootstrap-emu → $TARGET_ORG (source=$SOURCE_ORG, visibility=$VISIBILITY) ==="
echo "    bridge model: source token reads $SOURCE_ORG, target token writes $TARGET_ORG"
echo

# Helper: gh as source identity (reads public DevExpGbb)
gh_src() { GH_TOKEN="$GH_TOKEN_SOURCE" gh "$@"; }
# Helper: gh as target identity (writes EMU org)
gh_tgt() { GH_TOKEN="$GH_TOKEN_TARGET" gh "$@"; }

# Preflight: confirm both tokens work
if ! $DRY_RUN; then
  src_user=$(gh_src api user --jq .login 2>/dev/null || echo "")
  tgt_user=$(gh_tgt api user --jq .login 2>/dev/null || echo "")
  [[ -z "$src_user" ]] && { echo "❌ GH_TOKEN_SOURCE invalid (cannot resolve user)"; exit 2; }
  [[ -z "$tgt_user" ]] && { echo "❌ GH_TOKEN_TARGET invalid (cannot resolve user)"; exit 2; }
  echo "  source identity: $src_user"
  echo "  target identity: $tgt_user"
  if ! gh_src api "repos/$SOURCE_ORG/zava-agent-config" >/dev/null 2>&1; then
    echo "❌ source token cannot read $SOURCE_ORG/zava-agent-config"; exit 2
  fi
  if ! gh_tgt api "orgs/$TARGET_ORG" >/dev/null 2>&1; then
    echo "❌ target token cannot read org $TARGET_ORG (need admin:org)"; exit 2
  fi
  echo
fi

# 1. Mirror clone + create + push --mirror per repo
for r in "${REPOS[@]}"; do
  echo "--- $r ---"
  if $DRY_RUN; then
    echo "  [DRYRUN] would: gh repo clone $SOURCE_ORG/$r --mirror (source token)"
    echo "  [DRYRUN] would: gh repo create $TARGET_ORG/$r --$VISIBILITY (target token)"
    echo "  [DRYRUN] would: git push --mirror to $TARGET_ORG/$r"
    echo "  [DRYRUN] would: enable Actions on $TARGET_ORG/$r via API"
    continue
  fi

  if gh_tgt api "repos/$TARGET_ORG/$r" >/dev/null 2>&1; then
    echo "  ✅ $TARGET_ORG/$r already exists, skipping mirror+create"
  else
    echo "  → mirror-cloning $SOURCE_ORG/$r (source identity)"
    rm -rf "$WORK/$r.mirror"
    GH_TOKEN="$GH_TOKEN_SOURCE" git clone --mirror \
      "https://x-access-token:$GH_TOKEN_SOURCE@github.com/$SOURCE_ORG/$r.git" \
      "$WORK/$r.mirror" --quiet

    echo "  → creating $TARGET_ORG/$r (target identity, $VISIBILITY)"
    gh_tgt repo create "$TARGET_ORG/$r" "--$VISIBILITY" \
      --description "Mirrored from $SOURCE_ORG/$r for EMU workshop" >/dev/null

    echo "  → pushing --mirror to $TARGET_ORG/$r (target identity)"
    cd "$WORK/$r.mirror"
    git push --mirror \
      "https://x-access-token:$GH_TOKEN_TARGET@github.com/$TARGET_ORG/$r.git" --quiet
    cd "$WORK"
  fi

  # Enable Actions on the target repo. EMU enterprises with selected-actions
  # policy may reject 'all' — caller may need to adjust enterprise policy.
  echo '{"enabled":true,"allowed_actions":"all"}' \
    | gh_tgt api -X PUT "repos/$TARGET_ORG/$r/actions/permissions" --input - >/dev/null 2>&1 \
    || echo "  ⚠️  could not enable Actions on $TARGET_ORG/$r — check enterprise actions policy"
  echo
done

# 2. Rewrite refs in each repo: $SOURCE_ORG/ → $TARGET_ORG/
$DRY_RUN && { echo "🔍 DRY-RUN: skipping ref-rewrite phase"; echo; }
$DRY_RUN || for r in "${REPOS[@]}"; do
  echo "--- rewriting refs in $TARGET_ORG/$r ---"
  rm -rf "$WORK/$r"
  GH_TOKEN="$GH_TOKEN_TARGET" git clone --quiet \
    "https://x-access-token:$GH_TOKEN_TARGET@github.com/$TARGET_ORG/$r.git" "$WORK/$r"
  cd "$WORK/$r"

  hits=$(grep -rl "$SOURCE_ORG/" --include="*.yml" --include="*.yaml" --include="*.md" --include="*.json" . 2>/dev/null | grep -v "^./.git/" || true)
  if [[ -z "$hits" ]]; then
    echo "  ✅ no $SOURCE_ORG/ refs found, skipping"
    cd "$WORK"
    continue
  fi
  echo "  → rewriting in:"
  echo "$hits" | sed 's/^/      /'
  echo "$hits" | xargs sed -i.bak "s|$SOURCE_ORG/|$TARGET_ORG/|g"
  find . -name "*.bak" -delete

  if git diff --quiet; then
    echo "  ✅ no diff after rewrite (already clean)"
  else
    git -c user.name="Zava Workshop Kit" -c user.email="zava-kit@example.com" \
      commit -am "chore: rewrite source-org refs $SOURCE_ORG → $TARGET_ORG

Generated by zava-workshop-kit/bin/bootstrap-emu.sh."
    echo "  ✅ committed rewrites"
  fi

  # APM lockfile regen (same logic as public bootstrap)
  if [[ -f apm.yml ]] && command -v apm >/dev/null 2>&1; then
    echo "  → regenerating apm.lock.yaml against $TARGET_ORG content"
    if apm install --update >/dev/null 2>&1; then
      if [[ -f apm.lock.yaml ]] && ! git diff --quiet apm.lock.yaml 2>/dev/null; then
        git -c user.name="Zava Workshop Kit" -c user.email="zava-kit@example.com" \
          commit -m "chore(apm): regenerate lockfile against $TARGET_ORG plugins" apm.lock.yaml
        echo "  ✅ lockfile regenerated"
      elif [[ -f apm.lock.yaml ]]; then
        echo "  ✅ lockfile already current"
      else
        echo "  ✅ no apm dependencies — lockfile not needed"
      fi
    else
      echo "  ⚠️  apm install --update failed — push and regenerate manually"
    fi
  elif [[ -f apm.yml ]]; then
    echo "  ⚠️  apm.yml present but 'apm' CLI not on PATH — skipping lockfile regen"
  fi

  if ! git diff --quiet origin/HEAD HEAD 2>/dev/null; then
    git push origin HEAD --quiet
    echo "  ✅ pushed"
  fi
  cd "$WORK"
done

# 3. Org .github repo + apm-policy.yml
echo
echo "--- org policy: $TARGET_ORG/.github ---"
if ! $DRY_RUN && ! gh_tgt api "repos/$TARGET_ORG/.github" >/dev/null 2>&1; then
  echo "  → creating $TARGET_ORG/.github ($VISIBILITY)"
  gh_tgt repo create "$TARGET_ORG/.github" "--$VISIBILITY" \
    --description "Org defaults for $TARGET_ORG" --add-readme >/dev/null
  sleep 3
fi
if $DRY_RUN; then
  echo "  [DRYRUN] would create $TARGET_ORG/.github ($VISIBILITY) and template apm-policy.yml"
else
  rm -rf "$WORK/.github"
  GH_TOKEN="$GH_TOKEN_TARGET" git clone --quiet \
    "https://x-access-token:$GH_TOKEN_TARGET@github.com/$TARGET_ORG/.github.git" "$WORK/.github"
  cd "$WORK/.github"

  if [[ -f apm-policy.yml ]] && ! $FORCE; then
    backup="apm-policy.yml.bak.$(date +%Y%m%d-%H%M%S)"
    cp apm-policy.yml "$backup"
    echo "  ⚠️  existing apm-policy.yml backed up to $backup"
  fi

  sed "s|YOUR_ORG|$TARGET_ORG|g" "$KIT_DIR/templates/apm-policy.yml" > apm-policy.yml

  if [[ -f "${backup:-/dev/null}" ]] && diff -q apm-policy.yml "$backup" >/dev/null 2>&1; then
    echo "  ✅ apm-policy.yml unchanged"
    rm -f "$backup"
  else
    git add apm-policy.yml
    if git diff --cached --quiet; then
      echo "  ✅ apm-policy.yml already in place"
    else
      git -c user.name="Zava Workshop Kit" -c user.email="zava-kit@example.com" \
        commit -m "chore: org-level apm-policy.yml from zava-workshop-kit"
      git push origin HEAD --quiet || true
      echo "  ✅ apm-policy.yml committed"
    fi
  fi
  cd "$WORK"
fi

# 4. Trigger marketplace release on the target. Mirror push already brought
# tags over, but tag-push from --mirror does NOT fire workflows (mirror push
# uses the create-ref event, which is suppressed for mirror pushes). Re-push
# the tag explicitly to trigger release.yml.
echo
echo "--- triggering release on $TARGET_ORG/zava-agent-config ---"
if $DRY_RUN; then
  echo "  [DRYRUN] would re-push latest tag to fire release.yml"
else
  LATEST_TAG=$(gh_src api "repos/$SOURCE_ORG/zava-agent-config/releases/latest" --jq .tag_name 2>/dev/null || echo "")
  if [[ -z "$LATEST_TAG" ]]; then
    echo "  ⚠️  could not read latest tag from source"
  elif gh_tgt api "repos/$TARGET_ORG/zava-agent-config/releases/tags/$LATEST_TAG" >/dev/null 2>&1; then
    echo "  ✅ release $LATEST_TAG already published"
  else
    cd "$WORK/zava-agent-config"
    # Force re-push the tag to trigger release.yml (mirror push suppresses events)
    git push --force \
      "https://x-access-token:$GH_TOKEN_TARGET@github.com/$TARGET_ORG/zava-agent-config.git" \
      "refs/tags/$LATEST_TAG:refs/tags/$LATEST_TAG" --quiet 2>/dev/null \
      || echo "  ⚠️  tag re-push failed — push tag manually to trigger release.yml"
    echo "  → tag $LATEST_TAG re-pushed; release.yml should fire within ~30s"
    cd "$WORK"
  fi
fi

echo
if $DRY_RUN; then
  echo "=== 🔍 dry-run complete (no state modified) ==="
else
  echo "=== ✅ bootstrap-emu complete ==="
  echo "   workspace: $WORK"
  echo "   next: GH_TOKEN=\$GH_TOKEN_TARGET ./bin/smoke.sh --org=$TARGET_ORG"
  echo "   undo: GH_TOKEN_TARGET=\$GH_TOKEN_TARGET ./bin/teardown-emu.sh --target-org=$TARGET_ORG"
fi
