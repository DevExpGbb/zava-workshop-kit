# Azure SRE Agent — optional D5 finale setup

The D5 Meeting-to-code demo's final leg is: **Azure SRE Agent receives an alert → opens a remediation PR**. This requires Azure SRE Agent provisioned against a deployed instance of `zava-storefront`.

**Skip this doc entirely if you're cutting D5's SRE leg** — the rest of the workshop runs without Azure.

## What you need

1. An Azure subscription with **Azure SRE Agent** preview access enabled
2. A deployed `zava-storefront` instance (App Service or Container Apps — the kit doesn't provision this, see "Deployment" below)
3. A managed identity with `Contributor` on the SRE Agent resource group + GitHub permissions to open PRs

## Deployment of zava-storefront

Out of scope for this kit. The repo includes a Dockerfile; pick your favorite IaC + deployment tool. Two paths:

- **Azure-native:** `az containerapp up` from the repo root with `--source .`
- **Anywhere:** Docker image built from the repo, pushed to any registry, deployed to anything

What matters for the SRE demo: the running instance must emit traces/logs that SRE Agent's monitor can pick up.

## Wiring SRE Agent to GitHub

1. Provision SRE Agent in your subscription (preview portal — see Azure docs)
2. Configure its monitor to watch your `zava-storefront` deployment
3. Grant the SRE Agent's identity GitHub access to `YOUR_ORG/zava-storefront` via GitHub App or PAT
4. Set the alert threshold low enough to fire during a demo (e.g., trigger on a single 500 response)

## Demo-time choreography

1. Trigger a synthetic error against the deployed app (curl an endpoint that 500s)
2. SRE Agent detects + diagnoses
3. SRE Agent opens a PR against `YOUR_ORG/zava-storefront` proposing the fix
4. The same `pr-review-panel.yml` workflow that runs on human PRs reviews the SRE Agent's PR — closing the loop

## Fallback

If SRE Agent setup blocks: cut to a recording for D5's final 90 seconds. The narrative still works because the *story* is "agent saw production problem → opened PR" — humans can imagine the rest.
