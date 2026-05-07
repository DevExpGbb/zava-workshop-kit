#!/usr/bin/env bash
# teardown-emu.sh — remove workshop bundle from an EMU org
# Usage: GH_TOKEN_TARGET=ghp_emu ./bin/teardown-emu.sh --target-org=YOUR_EMU_ORG [--yes]
set -euo pipefail

TARGET_ORG=""
YES=false
for a in "$@"; do
  case "$a" in
    --target-org=*) TARGET_ORG="${a#--target-org=}" ;;
    --yes) YES=true ;;
    *) echo "unknown arg: $a"; exit 2 ;;
  esac
done
[[ -z "$TARGET_ORG" ]] && { echo "usage: $0 --target-org=<emu-org> [--yes]"; exit 2; }
[[ -z "${GH_TOKEN_TARGET:-}" ]] && { echo "❌ GH_TOKEN_TARGET not set (need delete_repo + admin:org scopes)"; exit 2; }

REPOS=(zava-storefront zava-agent-config poisoned-tracing-skill zava-skills-workshop-template)

gh_tgt() { GH_TOKEN="$GH_TOKEN_TARGET" gh "$@"; }

echo "=== teardown-emu → $TARGET_ORG ==="
echo "Will delete (if present):"
for r in "${REPOS[@]}"; do echo "  - $TARGET_ORG/$r"; done
echo "Will remove (if present):"
echo "  - org secrets COPILOT_GITHUB_TOKEN, GH_AW_PLUGINS_TOKEN"
echo "  - org rulesets tag-immutability, apm-audit-required"
echo
echo "NOT touched: $TARGET_ORG/.github (delete manually if desired)"
echo

if [[ "$YES" != "true" ]]; then
  read -rp "Type the org name '$TARGET_ORG' to confirm: " confirm
  [[ "$confirm" != "$TARGET_ORG" ]] && { echo "aborted"; exit 1; }
fi

for r in "${REPOS[@]}"; do
  if gh_tgt api "repos/$TARGET_ORG/$r" >/dev/null 2>&1; then
    echo "→ deleting $TARGET_ORG/$r"
    gh_tgt repo delete "$TARGET_ORG/$r" --yes
  else
    echo "  (already gone) $TARGET_ORG/$r"
  fi
done

for s in COPILOT_GITHUB_TOKEN GH_AW_PLUGINS_TOKEN; do
  if gh_tgt api "orgs/$TARGET_ORG/actions/secrets/$s" >/dev/null 2>&1; then
    echo "→ deleting org secret $s"
    GH_TOKEN="$GH_TOKEN_TARGET" gh secret delete "$s" --org "$TARGET_ORG"
  fi
done

for rs in tag-immutability apm-audit-required; do
  rid=$(gh_tgt api "orgs/$TARGET_ORG/rulesets" --jq ".[] | select(.name==\"$rs\") | .id" 2>/dev/null || echo "")
  if [[ -n "$rid" && "$rid" =~ ^[0-9]+$ ]]; then
    echo "→ deleting ruleset $rs (id=$rid)"
    gh_tgt api "orgs/$TARGET_ORG/rulesets/$rid" --method DELETE
  fi
done

echo
echo "✅ teardown-emu complete"
