#!/usr/bin/env bash
# smoke.sh — end-to-end verification: open PR, label, wait, assert green
# Usage: ./bin/smoke.sh --org=YOUR_ORG
set -euo pipefail

ORG=""
TIMEOUT=600   # seconds
for a in "$@"; do
  case "$a" in
    --org=*) ORG="${a#--org=}" ;;
    --timeout=*) TIMEOUT="${a#--timeout=}" ;;
    *) echo "unknown arg: $a"; exit 2 ;;
  esac
done
[[ -z "$ORG" ]] && { echo "usage: $0 --org=<github-org> [--timeout=600]"; exit 2; }

REPO="$ORG/zava-storefront"
WORK="${WORK:-/tmp/zava-smoke-$ORG}"
BRANCH="smoke/kit-$(date +%s)"

echo "=== smoke test → $REPO ==="

if ! gh api "repos/$REPO" >/dev/null 2>&1; then
  echo "❌ $REPO not found — run bootstrap.sh first"
  exit 1
fi

rm -rf "$WORK"
gh repo clone "$REPO" "$WORK" -- --quiet
cd "$WORK"

git checkout -b "$BRANCH"
echo "<!-- zava-workshop-kit smoke test $(date -u +%FT%TZ) -->" >> README.md
git -c user.name="Zava Workshop Kit" -c user.email="zava-kit@example.com" commit -am "test: smoke test from zava-workshop-kit"
git push origin "$BRANCH"

echo "→ opening PR"
PR_URL=$(gh pr create --repo "$REPO" --base main --head "$BRANCH" \
  --title "[smoke] zava-workshop-kit verification" \
  --body "Automated smoke test from zava-workshop-kit/bin/smoke.sh — safe to close.")
PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')
echo "  PR #$PR_NUM: $PR_URL"

echo "→ labeling 'panel-review'"
gh pr edit "$PR_NUM" --repo "$REPO" --add-label "panel-review" 2>/dev/null \
  || gh label create "panel-review" --repo "$REPO" --color "0e8a16" --description "Trigger PR Review Panel" \
     && gh pr edit "$PR_NUM" --repo "$REPO" --add-label "panel-review"

echo "→ waiting for pr-review-panel workflow run (timeout=${TIMEOUT}s)"
deadline=$(( $(date +%s) + TIMEOUT ))
status=""
conclusion=""
run_id=""

while [[ $(date +%s) -lt $deadline ]]; do
  # Find workflow run for this PR's HEAD sha
  HEAD_SHA=$(git rev-parse HEAD)
  run_id=$(gh run list --repo "$REPO" --workflow pr-review-panel.lock.yml --limit 5 --json databaseId,headSha,status,conclusion --jq ".[] | select(.headSha==\"$HEAD_SHA\") | .databaseId" 2>/dev/null | head -1 || true)
  if [[ -n "$run_id" ]]; then
    state=$(gh run view "$run_id" --repo "$REPO" --json status,conclusion --jq '"\(.status):\(.conclusion)"')
    status=${state%%:*}
    conclusion=${state##*:}
    echo "  run $run_id status=$status conclusion=$conclusion"
    if [[ "$status" == "completed" ]]; then
      break
    fi
  else
    echo "  (no run yet — waiting)"
  fi
  sleep 15
done

echo "→ cleaning up"
gh pr close "$PR_NUM" --repo "$REPO" --delete-branch 2>/dev/null || true

if [[ "$conclusion" == "success" ]]; then
  echo
  echo "OK ✅ smoke test green — workshop is live"
  exit 0
elif [[ -z "$run_id" ]]; then
  echo
  echo "❌ no workflow run appeared in ${TIMEOUT}s — check label name + workflow file"
  exit 1
else
  echo
  echo "❌ workflow concluded with: $conclusion (run $run_id)"
  echo "   gh run view $run_id --repo $REPO --log"
  exit 1
fi
