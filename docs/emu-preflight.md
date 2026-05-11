# EMU pre-flight — platform admin checklist

Run this **5–7 days before** the workshop. Five items, ~30 minutes of admin work. Each can be done independently. Workshop morning is a "no new infrastructure" window — anything not green here will block attendees and is much harder to fix live.

This page assumes you are deploying the workshop into a GitHub Enterprise Cloud org with **EMU (Enterprise Managed Users) enabled**. For regular `github.com` orgs (no EMU), the only relevant items are #2 and #5 — the others are EMU-specific gates.

---

## 1. PAT issuance enabled at the enterprise level

`gh aw` workflows that use `engine: copilot` require a `COPILOT_GITHUB_TOKEN` secret. Per the [upstream auth reference](https://github.github.com/gh-aw/reference/auth/#copilot_github_token), this **must** be a fine-grained Personal Access Token — GitHub Apps, OAuth tokens, and classic PATs are not supported.

EMU enterprises commonly have fine-grained PAT issuance **disabled by default** for all members. Verify:

- **Enterprise → Settings → Authentication security → Personal access tokens** (or **Policies → Personal access tokens** on newer UIs)
- **Fine-grained personal access tokens** must be set to **Allowed** for at least the EMU group/account that will own this token.
- If the policy is `Restricted`, add the specific user to the allowlist or temporarily relax for the workshop window.

You only need PAT issuance enabled for **one** EMU account — the one that will mint `COPILOT_GITHUB_TOKEN`. Attendees do not need their own PATs.

## 2. Copilot seat for the PAT owner

The EMU account that issues `COPILOT_GITHUB_TOKEN` must have an **active Copilot Business or Copilot Enterprise** seat. Without this, the inference call fails with `403 Resource not accessible by personal access token` even when the token is otherwise correctly configured.

Verify in **Enterprise → Copilot → Access** that the chosen account appears in the seat list. If not, assign a seat (or pick a different EMU account that already has one).

For attendees who will trigger workflows: they also each need a Copilot seat to run the workshop's IDE-side work, but the `gh aw` workflow itself uses the PAT owner's seat for the Actions-side inference, not the trigger user's.

## 3. Actions allowlist includes everything the workflows call

If the enterprise uses `selected_actions` mode, **Enterprise → Policies → Actions → Allow specified actions** must include, at minimum:

- `actions/checkout@*`
- `actions/setup-node@*`
- `actions/upload-artifact@*`
- `actions/github-script@*`
- **`github/gh-aw/actions/setup-cli@*`** — gh-aw's own setup action (often missed)
- **`microsoft/apm-action@*`** — used by the `shared/apm.md` import block in track workflows

If the enterprise uses `all` mode for Actions, this item is automatically satisfied. If `local_only`, you'll need to mirror these actions into the enterprise's internal mirror — out of scope for this workshop kit; talk to your platform team well before workshop day.

## 4. Runner egress

GitHub-hosted runners need outbound HTTPS to:

- `api.githubcopilot.com` — Copilot inference endpoint
- `objects.githubusercontent.com` — release tarball downloads (the `imports.packages` block pulls these)
- `ghcr.io` — only if any workflow uses container-based actions

If your enterprise routes runner traffic through an egress proxy or has a deny-list, confirm these three are reachable. Default GitHub-hosted runner egress is fully open and this item is automatically satisfied; self-hosted runners often are not.

## 5. Org secret with the right visibility

```bash
gh secret set COPILOT_GITHUB_TOKEN --org YOUR_ORG --visibility=all
```

`--visibility=all` makes the secret available to every repo in the org, including any new repos attendees create from the workshop template. The alternative is `--visibility=selected` with an explicit allowlist, in which case you must update the allowlist each time a new attendee repo is created — error-prone for live workshops.

Verify:

```bash
gh secret list --org YOUR_ORG
# COPILOT_GITHUB_TOKEN  Updated YYYY-MM-DD  Visibility: all
```

If you ran `bin/bootstrap-emu.sh` end-to-end, this is already done. The smoke step is to trigger one `gh aw` workflow on a pre-staged repo and confirm it succeeds. See [`live-workshop-runbook.md`](live-workshop-runbook.md) for the smoke procedure.

---

## What attendees DO NOT need

To preempt the most common live-workshop confusion:

- Attendees do **not** create their own PATs.
- Attendees do **not** set `COPILOT_GITHUB_TOKEN` on their fork/template repo. The org secret with visibility=all covers them.
- Attendees do **not** need elevated GitHub permissions beyond standard EMU member access.

If an attendee's workflow fails at the Copilot step with a `401` or `403`, the cause is almost always one of the five items on this checklist, not anything in the attendee's code.

---

## Troubleshooting cross-reference

| Symptom | Likely item from this checklist |
|---|---|
| `403 Resource not accessible by personal access token` | #1 (wrong PAT type), #2 (no Copilot seat) |
| `Workflow not allowed: github/gh-aw/actions/setup-cli` | #3 (Actions allowlist) |
| `Error: secret COPILOT_GITHUB_TOKEN not found` in workflow log | #5 (secret missing or wrong visibility) |
| `apm install` failures fetching tarball | #4 (egress to `objects.githubusercontent.com`) |
| All workflows queued and never start | #3 (Actions disabled at enterprise level) |

Each of these is easier to fix at T-7 than at T-0. That's the entire point of this checklist.
