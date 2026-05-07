# Copilot plan requirements

The workshop uses GitHub Copilot in three places. Each has minimum plan requirements.

## Where Copilot is used

| Use | Triggered by | Requires |
|---|---|---|
| `gh aw` workflows (PR Review Panel, Triage Panel) | A label on a PR or issue | **Copilot Business** or **Copilot Enterprise** with the user identity on `COPILOT_GITHUB_TOKEN` having a seat |
| Trainee IDE work in workshop-template | The trainee's personal IDE | A Copilot seat assigned to the trainee's user account |
| Coding Agent in D5 demo (optional) | Issue assigned to `@copilot` | Copilot Business+ with Coding Agent enabled in org settings |

## Plan minimums

- **Evaluation / proof-of-concept:** Copilot Individual works for the trainee IDE part but **not** for the `gh aw` workflows or Coding Agent. You'd lose the headliner demos.
- **Real workshop:** **Copilot Business** is the minimum. One seat assigned to the bot user (whoever owns `COPILOT_GITHUB_TOKEN`) plus one seat per trainee.
- **D5 finale:** Coding Agent must be enabled at org level — **Settings → Copilot → Policies → "Coding Agent"** = Allowed. Available on Business and Enterprise.

## Seat math example

For a 12-trainee workshop with 1 facilitator:
- 12 × Copilot Business seats (trainees)
- 1 × Copilot Business seat (the bot identity used by `gh aw`)
- 1 × Copilot Business seat (the facilitator)
- = **14 seats**, ~$240/month at standard pricing (cancel after the workshop month)

## Verifying Copilot is live in your org

```bash
gh api orgs/YOUR_ORG/copilot/billing
```

Should return JSON with `seat_management_setting` set to something other than `null`.

## What if I don't have Copilot Business?

You can still run the workshop in a degraded mode:
- Demo the `gh aw` workflows from a **recording** instead of live (`bin/smoke.sh` won't pass)
- Trainees use Copilot Individual for their IDE work
- Skip the D5 Coding Agent leg

Decide before workshop day; don't surprise trainees.
