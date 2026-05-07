# Inventory — what's in this kit

The Zava workshop bundle is four repos plus org configuration. Here's what each piece does and how they compose.

## Repository graph

```
   ┌────────────────────────────────────────────────────────┐
   │  YOUR_ORG/.github  (org config)                        │
   │  └─ apm-policy.yml  ── allowlist for apm install       │
   └────────────────────────────────────────────────────────┘
                              │
                              │ enforced on
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │  YOUR_ORG/zava-agent-config  (the marketplace)         │
   │  ├─ plugins/secure-baseline/  ← always pinned          │
   │  ├─ plugins/ideate-kit/       ← meeting-to-issue       │
   │  ├─ plugins/code-kit/         ← write/refactor         │
   │  ├─ plugins/review-kit/       ← PR Review Panel        │
   │  ├─ plugins/release-kit/      ← CI/CD                  │
   │  ├─ plugins/operate-kit/      ← SRE → remediation      │
   │  └─ .github/workflows/        ← apm-audit, release     │
   │                                                         │
   │     Releases: v5.0.1 (latest)                          │
   └────────────────────────────────────────────────────────┘
                              │
                  pinned by   │
       ┌──────────────────────┼──────────────────────┐
       ▼                      ▼                      ▼
   ┌────────────┐       ┌────────────┐       ┌──────────────┐
   │ zava-      │       │ zava-      │       │ poisoned-    │
   │ storefront │       │ skills-    │       │ tracing-     │
   │            │       │ workshop-  │       │ skill        │
   │ Demo Node  │       │ template   │       │              │
   │ app + PR   │       │            │       │ Hidden-      │
   │ Review +   │       │ Trainee    │       │ Unicode      │
   │ Triage gh  │       │ starter    │       │ payload —    │
   │ aw flows   │       │ (Use this  │       │ used to      │
   │            │       │ template)  │       │ demo apm     │
   │            │       │            │       │ install      │
   │            │       │            │       │ rejection    │
   └────────────┘       └────────────┘       └──────────────┘
```

## Why each piece exists

### `zava-agent-config` — the marketplace
This is **the product claim of APM**: a versioned, releasable, polyglot marketplace of Agent Skills, instructions, and shared bootstraps. Every other repo in this bundle pins kits from here.

The 6 plugins map to SDLC phases:
- **secure-baseline** — security/governance scaffolding pinned by every repo
- **ideate-kit** — meeting → issue conversion (Block 1 / D5 demo)
- **code-kit** — refactor + write loops (Block 2 / D1 demo)
- **review-kit** — PR Review Panel (Block 2 / D1+D2 demo)
- **release-kit** — CI/CD + tagging (Block 2)
- **operate-kit** — SRE Agent → remediation PR (Block 2 / D5 finale)

### `zava-storefront` — the demo target
A small Node.js storefront. Pre-wired with two `gh aw` workflows that consume `review-kit`:
- `pr-review-panel.yml` — label a PR `panel-review`, get a multi-skill review (security, perf, tests)
- `triage-panel.yml` — label an issue `triage`, get classification + assignment recommendation

This is what you demo in D1 Velocity (PR opened → panel reviews → fixes proposed).

### `zava-skills-workshop-template` — the trainee starter
Marked `is_template=true`. Trainees click **"Use this template"** to fork it into the org, then build their first Agent Skill in `.apm/skills/my-skill/`. Includes a `sample-app/` (Node calculator) for the skill to operate on, and a pre-compiled `gh aw` workflow that runs the skill on labeled PRs.

### `poisoned-tracing-skill` — the supply chain demo
A deliberately compromised skill. Try to `apm install` it pinned in your `apm.yml` — `apm-audit` rejects it because the SKILL.md contains hidden-Unicode payloads. This is D3 Defender Act I.

### Org `.github` repo — the policy host
Hosts `apm-policy.yml` at the org level. APM reads this policy when `apm install` runs in any repo in the org and uses it to allowlist/blocklist plugins. Without this file, anyone can pin anything.

## Token + secret graph

```
        ┌─────────────────────────────┐
        │ Org secrets (visibility=all)│
        ├─────────────────────────────┤
        │ COPILOT_GITHUB_TOKEN        │ ← used by gh aw to invoke Copilot
        │ GH_AW_PLUGINS_TOKEN         │ ← used by gh aw to pull plugins
        └─────────────────────────────┘
                       │
                       ▼ inherited by
        ┌──────────────────────────────────────┐
        │ Every workflow in every zava-* repo  │
        └──────────────────────────────────────┘
```

## Ruleset graph

```
        ┌─────────────────────────────────┐
        │ Org rulesets (Settings → Rules) │
        ├─────────────────────────────────┤
        │ tag-immutability   (mandatory)  │ ← protects all v* tags
        │ apm-audit-required (recommended)│ ← gates apm.yml PRs
        └─────────────────────────────────┘
```

## Versioning model

- **Marketplace versions:** `zava-agent-config` releases as `vMAJOR.MINOR.PATCH`. Consuming repos pin at plugin level: `YOUR_ORG/zava-agent-config/plugins/code-kit#v5.0.1`.
- **Workshop bundle version:** this kit's `README.md` always reflects the latest tested marketplace version. As of this release: `v5.0.1`.
- **Trainee skills:** trainees version their own skills independently in their template forks.

## What this kit does NOT include

- The slide deck, runbooks, or backup recordings — those are workshop facilitator artifacts shipped separately
- `zava-platform` (deprecated — replaced by storefront fan-out demo for the modernizer track)
- Any Microsoft tenant-specific Azure resources (see `docs/azure-sre.md` if you want optional D5 finale)
