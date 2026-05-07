#!/usr/bin/env bash
# preflight.sh — verify the target org is ready for bootstrap
# Usage: ./bin/preflight.sh --org=YOUR_ORG
set -euo pipefail

ORG=""
for a in "$@"; do
  case "$a" in
    --org=*) ORG="${a#--org=}" ;;
    *) echo "unknown arg: $a"; exit 2 ;;
  esac
done
[[ -z "$ORG" ]] && { echo "usage: $0 --org=<github-org>"; exit 2; }

PASS="✅"
FAIL="❌"
WARN="⚠️ "
errors=0

ok()    { echo "$PASS $1"; }
fail()  { echo "$FAIL $1"; errors=$((errors+1)); }
warn()  { echo "$WARN $1"; }

echo "=== preflight: $ORG ==="
echo

# 1. gh CLI present + authenticated
if ! command -v gh >/dev/null 2>&1; then
  fail "gh CLI not installed — see https://cli.github.com"
else
  ok "gh CLI present ($(gh --version | head -1))"
fi

if ! gh auth status >/dev/null 2>&1; then
  fail "gh CLI not authenticated — run 'gh auth login'"
else
  ok "gh CLI authenticated as $(gh api user --jq .login)"
fi

# 2. org exists + we can read it
if ! gh api "orgs/$ORG" >/dev/null 2>&1; then
  fail "org '$ORG' not visible — does it exist? are you a member?"
else
  ok "org '$ORG' visible"
fi

# 3. we are an org owner (best-effort: check membership role)
role=$(gh api "orgs/$ORG/memberships/$(gh api user --jq .login)" --jq .role 2>/dev/null || echo "unknown")
if [[ "$role" == "admin" ]]; then
  ok "you are an admin of '$ORG'"
elif [[ "$role" == "member" ]]; then
  warn "you are a member of '$ORG' but not admin — rulesets + secrets steps will fail"
else
  warn "could not determine your role in '$ORG' (got: $role)"
fi

# 4. org secrets — checked but only the names; values not validated
for s in COPILOT_GITHUB_TOKEN GH_AW_PLUGINS_TOKEN; do
  if gh api "orgs/$ORG/actions/secrets/$s" >/dev/null 2>&1; then
    ok "org secret '$s' present"
  else
    warn "org secret '$s' missing — bootstrap will prompt or fail"
  fi
done

# 5. rulesets — list + look for our two
rulesets_json=$(gh api "orgs/$ORG/rulesets" 2>/dev/null || echo "[]")
for rs in tag-immutability apm-audit-required; do
  if echo "$rulesets_json" | grep -q "\"name\":\"$rs\""; then
    ok "ruleset '$rs' present"
  else
    warn "ruleset '$rs' missing — apply from templates/ or run bootstrap"
  fi
done

# 6. Copilot plan — best-effort check via billing API (admins only)
if cop=$(gh api "orgs/$ORG/copilot/billing" 2>/dev/null); then
  seat_mgmt=$(echo "$cop" | grep -o '"seat_management_setting":"[^"]*"' | cut -d'"' -f4)
  if [[ -n "$seat_mgmt" ]]; then
    ok "Copilot enabled on org (seat_management=$seat_mgmt)"
  else
    warn "Copilot billing endpoint returned no seat info"
  fi
else
  warn "could not query Copilot billing — verify Copilot Business/Enterprise is active for '$ORG'"
fi

# 7. source repos in DevExpGbb reachable
for r in zava-agent-config zava-storefront zava-skills-workshop-template poisoned-tracing-skill; do
  if gh api "repos/DevExpGbb/$r" >/dev/null 2>&1; then
    ok "source 'DevExpGbb/$r' reachable"
  else
    fail "source 'DevExpGbb/$r' not reachable"
  fi
done

echo
if [[ $errors -gt 0 ]]; then
  echo "$FAIL preflight failed with $errors error(s) — fix the $FAIL lines above before bootstrap"
  exit 1
else
  echo "$PASS preflight passed — safe to run bootstrap.sh"
fi
