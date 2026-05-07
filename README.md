# Zava Workshop Kit

> **Deploy the Zava Agentic SDLC Workshop into your own GitHub org in 15 minutes.**

This kit is the one-stop entry point for org administrators (or curious individuals) who want to stand up the Zava agentic SDLC workshop in their own GitHub org — self-contained, no dependency on any external demo org.

> **Scope:** assumes **GitHub** (or GitHub Enterprise Cloud) + a **GitHub Copilot Business/Enterprise** plan in the consumer org. The bootstrap forks a deliberately compromised `poisoned-tracing-skill` repo as a supply-chain demo fixture — keep workshop deployments in a non-production org. This is an experiment / training kit, not a regulated-production runbook.

## What you get

After running the bootstrap, your org owns four working repos:

| Repo | Role |
|---|---|
| `zava-agent-config` | Marketplace of 6 reusable Agent Skills + APM kits (secure-baseline, ideate-kit, code-kit, review-kit, release-kit, operate-kit) |
| `zava-storefront` | A demo Node.js app pre-wired with PR Review Panel + Triage Panel `gh aw` workflows that consume the marketplace |
| `zava-skills-workshop-template` | Trainee starter — fork via "Use this template" to author your first Agent Skill |
| `poisoned-tracing-skill` | A deliberately compromised skill — used in the supply chain demo to show `apm install` rejecting hidden-Unicode payloads |

Plus org-level configuration: 2 secrets, 2 rulesets, 1 `apm-policy.yml`.

## Quickstart for org owners

```bash
# 1. Clone this kit
gh repo clone DevExpGbb/zava-workshop-kit && cd zava-workshop-kit

# 2. Verify your org is ready
./bin/preflight.sh --org=YOUR_ORG

# 3. Deploy the bundle
./bin/bootstrap.sh --org=YOUR_ORG

# 4. Confirm everything works end-to-end
./bin/smoke.sh --org=YOUR_ORG
```

If `smoke.sh` exits green, your workshop is live. Hand the trainees [`zava-skills-workshop-template`](#zava-skills-workshop-template-row-above) and tell them to click **"Use this template"**.

## Read next

- [`ORG-ADMIN-SETUP.md`](ORG-ADMIN-SETUP.md) — the full 7-step runbook with prereqs, token recipes, and ruleset config
- [`INVENTORY.md`](INVENTORY.md) — what each repo does, the dependency graph, and how the pieces compose
- [`docs/tokens.md`](docs/tokens.md) — exact PAT scopes for the two required org secrets
- [`docs/copilot-plan.md`](docs/copilot-plan.md) — which GitHub Copilot SKU you need and why
- [`docs/troubleshooting.md`](docs/troubleshooting.md) — common bootstrap failures and fixes
- [`docs/azure-sre.md`](docs/azure-sre.md) — optional Azure SRE Agent setup for the D5 finale demo

## Teardown

```bash
./bin/teardown.sh --org=YOUR_ORG    # removes all 4 repos + secrets + rulesets (idempotent)
```

## Status

This kit is the canonical home of the workshop bundle. The `hackathon-white-pig-8` org you may see referenced in older docs was an ephemeral workshop fixture and may be removed.

## License

MIT for the kit itself. Each consuming repo carries its own license.
