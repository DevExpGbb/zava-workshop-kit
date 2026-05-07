# Live workshop runbook — onsite delivery (with EMU contingencies)

This runbook covers operational delivery of the Zava workshop at a customer site, with explicit fallbacks for when `bin/bootstrap-emu.sh` fails or partially completes. **Workshop morning is a "no new infrastructure" window** — all bootstrap work happens days ahead.

If you're standing up a personal sandbox in your own public github.com org, skip this and use the [`README.md`](../README.md) quickstart. This runbook is for **scheduled, customer-facing, EMU-context delivery**.

---

## The pre-stage pattern

Treat the EMU enterprise as having two orgs in scope:

| Org | Role | Lifetime |
|---|---|---|
| `<customer>-platform` (e.g. `lloyds-platform`) | Holds the 4 mirrored repos at `--visibility=internal`. Read-only for attendees. | Persists across workshops. |
| `<customer>-workshop-NNNN` (e.g. `lloyds-workshop-2026-05`) | Per-cohort scratch org where attendees template-copy and experiment. | Disposable. Teardown after each cohort. |

Bridge engineer pre-stages **into the platform org once**, days before the workshop. Attendees only ever consume from it.

---

## T-7 days — pre-stage the platform org

Run from your bridge machine (laptop with both PATs available):

```bash
export GH_TOKEN_SOURCE=ghp_personal_xxx     # personal github.com PAT
export GH_TOKEN_TARGET=ghp_emu_xxx           # EMU PAT, admin on platform org

./bin/bootstrap-emu.sh --target-org=<customer>-platform --dry-run     # preview
./bin/bootstrap-emu.sh --target-org=<customer>-platform               # apply
```

If `bootstrap-emu.sh` succeeds end-to-end: you're done with infrastructure. Move to T-1 smoke testing.

If `bootstrap-emu.sh` partially completes or fails: drop to the [manual mirror cheatsheet](manual-mirror-cheatsheet.md). 4 commands per repo + 1 admin secret + Actions enable. ~30 min for a single engineer. The script is automation over those primitives — its absence is a productivity hit, not a blocker.

### One-time admin steps (script can't do these — they need org-owner UI access)

1. **Set `COPILOT_GITHUB_TOKEN` org secret** on `<customer>-platform`. The PAT must be issued by an EMU member account, scopes: `repo`, `workflow`. Verify in Settings → Secrets → Actions → Organization secrets.
2. **Set `COPILOT_GITHUB_TOKEN` org secret** also on `<customer>-workshop-NNNN` (or hand attendees instructions to set it on their own forks if your enterprise prefers per-repo secrets).
3. **Confirm enterprise Actions allowlist** permits at minimum: `actions/checkout`, `actions/setup-node`, `actions/upload-artifact`, `actions/github-script`. Confirm with the enterprise platform team — most enterprises permit GitHub-owned actions by default.

---

## T-1 day — smoke test the pre-staged org

```bash
GH_TOKEN=$GH_TOKEN_TARGET ./bin/smoke.sh --org=<customer>-platform
```

Expected: PR opens on `zava-storefront`, gets labeled `panel-review`, the `pr-review-panel.yml` workflow fires, exits within ~2 min.

If smoke fails, debug in the order:
1. Was `COPILOT_GITHUB_TOKEN` set as an **org** secret (not repo)? `gh secret list --org <customer>-platform`
2. Did `release.yml` actually publish? `gh release list --repo <customer>-platform/zava-agent-config` should show the latest tag with 6 plugin tarballs + `marketplace.json`.
3. Is the enterprise Actions allowlist permitting the workflow's actions? Look at the failed workflow run logs.

---

## T-0 morning — pre-flight (15 min before doors open)

1. `gh repo list <customer>-platform --visibility=internal` — confirm 4 repos present.
2. `gh release view --repo <customer>-platform/zava-agent-config v5.0.1` — confirm release assets exist.
3. Run `smoke.sh` once more against the platform org — confirm green.
4. Open `<customer>-workshop-NNNN/zava-skills-workshop-template` in the browser, confirm "Use this template" button is visible to a sample attendee account (have one nearby tester click it on their phone).

If any of those fails, you have ~15 min to either: (a) fix the specific repo via [manual mirror cheatsheet](manual-mirror-cheatsheet.md), or (b) downgrade to fallback mode (next section).

---

## T-0 fallback ladder — if something is broken at 9am

The workshop has **four progressively-degraded modes**. Pick the highest one that works and tell attendees up-front "we're operating in mode N today, here's what changes."

### Mode 1 — Everything works (target)
Attendees follow [README.md](../README.md) Quickstart from `<customer>-workshop-NNNN`. `apm install` from `<customer>-platform/zava-agent-config` Just Works. `gh aw` workflows fire on labels.

### Mode 2 — Repos mirrored but `release.yml` never fired (no marketplace assets)
Attendees clone normally. **Marketplace `apm install` fails** — the org's `zava-agent-config` repo has no published release assets. Workaround: use **`apm install ./path/to/local-skill`** instead. Pre-stage instruction:
```bash
git clone https://github.com/<customer>-platform/zava-agent-config ~/zava-agent-config
# Then in the workshop repo:
apm install ~/zava-agent-config/skills/secure-baseline
```
Frame this as "we'll teach the local-install path today, the marketplace path is identical." 95% of workshop content unaffected.

### Mode 3 — Some repos are missing or broken
Bridge engineer falls back to [manual mirror cheatsheet](manual-mirror-cheatsheet.md) during the first coffee break (15 min). Attendees work on what's available; missing repo gets restored before the relevant track. Tell attendees the schedule slip up-front — most are fine with it.

### Mode 4 — Cold storage rescue (network down or all GitHub paths blocked)
Pre-staged USB stick / SharePoint folder with:
- 4 git bundle files (`git bundle create REPO.bundle --all`)
- 6 plugin tarballs from the latest `zava-agent-config` release
- `apm` CLI installer for offline install
Attendees `git clone REPO.bundle` and `apm install ./tarball.tgz`. Most of the workshop still runs — the live PR-Review-Panel demo is the main casualty (needs Copilot API access).

---

## T+1 day — teardown the per-cohort org

The platform org persists. The per-cohort workshop org gets cleaned up:

```bash
GH_TOKEN_TARGET=$GH_TOKEN_TARGET ./bin/teardown-emu.sh --target-org=<customer>-workshop-NNNN --yes
```

Leave `<customer>-platform` in place for the next cohort.

---

## Bridge engineer day-of kit

Pack this on your laptop before traveling:

- `gh` CLI authed with both `GH_TOKEN_SOURCE` and `GH_TOKEN_TARGET` (test before leaving)
- This kit cloned: `git clone https://github.com/DevExpGbb/zava-workshop-kit`
- Cold-storage USB with bundles + tarballs (Mode 4 insurance)
- `docs/manual-mirror-cheatsheet.md` open in a tab
- This runbook open in a tab
- Phone-tethering option in case venue WiFi blocks GitHub API

---

## Why this works even without `bootstrap-emu.sh`

The script is **convenience automation over native git/gh primitives**. The underlying mechanism — mirror clone + push --mirror to a freshly-created internal repo — is a 2-command operation that GitHub fully supports for any user with admin on the target org. EMU does not block this; it only blocks `gh repo fork` (cross-identity) and public-repo creation. See [`docs/manual-mirror-cheatsheet.md`](manual-mirror-cheatsheet.md) for the 30-minute manual path.
