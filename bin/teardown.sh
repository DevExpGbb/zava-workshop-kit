#!/usr/bin/env bash
# teardown.sh — remove workshop bundle from your org (idempotent, destructive)
# Usage: ./bin/teardown.sh --org=YOUR_ORG [--yes]
set -euo pipefail

ORG=""
YES=false
for a in "$@"; do
  case "$a" in
    --org=*) ORG="${a#--org=}" ;;
    --yes) YES=true ;;
    *) echo "unknown arg: $a"; exit 2 ;;
  esac
done
[[ -z "$ORG" ]] && { echo "usage: $0 --org=<github-org> [--yes]"; exit 2; }

REPOS=(zava-storefront zava-agent-config poisoned-tracing-skill zava-skills-workshop-template)

echo "=== teardown → $ORG ==="
echo "Will delete (if present):"
for r in "${REPOS[@]}"; do echo "  - $ORG/$r"; done
echo "Will remove (if present):"
echo "  - org secrets COPILOT_GITHUB_TOKEN, GH_AW_PLUGINS_TOKEN"
echo "  - org rulesets tag-immutability, apm-audit-required"
echo
echo "NOT touched: $ORG/.github (delete manually if desired)"
echo

if [[ "$YES" != "true" ]]; then
  read -rp "Type the org name '$ORG' to confirm: " confirm
  [[ "$confirm" != "$ORG" ]] && { echo "aborted"; exit 1; }
fi

for r in "${REPOS[@]}"; do
  if gh api "repos/$ORG/$r" >/dev/null 2>&1; then
    echo "→ deleting $ORG/$r"
    gh repo delete "$ORG/$r" --yes
  else
    echo "  (already gone) $ORG/$r"
  fi
done

for s in COPILOT_GITHUB_TOKEN GH_AW_PLUGINS_TOKEN; do
  if gh api "orgs/$ORG/actions/secrets/$s" >/dev/null 2>&1; then
    echo "→ deleting org secret $s"
    gh secret delete "$s" --org "$ORG"
  fi
done

# Rulesets need ID lookup
for rs in tag-immutability apm-audit-required; do
  rid=$(gh api "orgs/$ORG/rulesets" --jq ".[] | select(.name==\"$rs\") | .id" 2>/dev/null || echo "")
  if [[ -n "$rid" ]]; then
    echo "→ deleting ruleset $rs (id=$rid)"
    gh api "orgs/$ORG/rulesets/$rid" --method DELETE
  fi
done

echo
echo "✅ teardown complete"
