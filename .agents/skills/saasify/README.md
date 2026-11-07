# saasify — turn any project into a SaaS

> A coding-agent skill that converts a regular, single-user app into a production-ready multi-tenant **SaaS** — authentication, organizations & teams, role-based permissions, plans & billing, invites and onboarding.

```bash
npx skills add dolevhayut/saasify
```

Works with **Claude Code · Cursor · Codex** and other coding agents. Free & open-source (MIT).

---

## Why

You built something great. It works. But to actually *sell* it, you hit the wall every SaaS needs and most side-projects skip:

- 🔓 **Auth** — no login / signup / sessions
- 🏢 **Multi-tenancy** — every customer sees the same data (a security nightmare)
- 👥 **Roles & permissions** — no admin, no members, no teams
- 💳 **Plans & billing** — how do you even charge? tiers? invoices?

`saasify` encodes years of real SaaS builds into one skill. It **detects what your project already has, reports the gaps, confirms scope with you, then builds the missing pillars in the right dependency order** — instead of you wiring it all by hand.

## The 4 pillars (built in order)

| Pillar | What you get |
|--------|--------------|
| 🔓 **Authentication** | Login/signup, sessions, OAuth, password reset, profiles |
| 🏢 **Multi-tenancy** | Organizations, `organization_id` scoping, **database-enforced isolation (RLS)** |
| 👥 **RBAC** | Owner/admin/member roles (or richer hierarchies), permission helpers, guards |
| 💳 **Plans & Billing** | Plan catalog, feature gating, usage limits — **Stripe, HYP/היפ (Israeli), license keys, credits** |

Plus the connective tissue: **invites & onboarding**.

## Install

**Interactive (pick your agent):**
```bash
npx skills add dolevhayut/saasify
```

**Global — all agents, no prompts:**
```bash
npx skills add dolevhayut/saasify --yes --global
```

**Project-local — all agents, no prompts:**
```bash
npx skills add dolevhayut/saasify --yes
```

The CLI auto-detects which agents you use:

| Agent | Install path |
|---|---|
| Amp, Antigravity, Cline, Codex, Cursor, Gemini CLI, GitHub Copilot, Warp, and more | `.agents/skills` (universal, always included) |
| Claude Code | `.claude/skills` |
| Aider | `.aider-desk/skills` |
| Augment | `.augment/skills` |

Or clone it manually into your agent's skills folder (e.g. `~/.claude/skills/saasify/`) — no build step.

## Use

Just ask your agent, in English or Hebrew:

```
turn this project into a SaaS
add login, organizations and plans
הפוך את הפרויקט הזה למערכת SaaS
תוסיף התחברות, ארגונים, הרשאות ומסלולי תשלום
```

The skill runs a gap analysis, asks a few scoping questions (tenancy model, billing gateway, plan tiers), then implements — pillar by pillar, verifying as it goes.

## What's inside

| File | Purpose |
|------|---------|
| `SKILL.md` | Orchestrator: the 4 pillars, workflow, principles |
| `references/00-gap-analysis.md` | Detect stack & what already exists |
| `references/01-auth.md` | Supabase Auth / NextAuth, login pages, profiles |
| `references/02-multitenancy-rls.md` | Orgs, `organization_id`, RLS, backfill |
| `references/03-rbac.md` | Roles, permission helpers, route guards |
| `references/04-billing-plans.md` | Plan catalog, Stripe, HYP/היפ, licenses, metering, feature gating |
| `references/05-onboarding-invites.md` | First-run onboarding + invite flow |
| `references/06-checklist.md` | Security & verification checklist |
| `assets/supabase/0001_saas_foundation.sql` | Ready-to-adapt foundation migration |

## Default stack

Supabase (Auth + Postgres + RLS) with Next.js or Vite/React, shadcn/ui, and Stripe + HYP for billing. The *patterns* are stack-agnostic — the references note Prisma / Drizzle / Firebase / NextAuth equivalents.

## Principles it enforces

1. Tenancy is enforced at the **database** (RLS), never the UI.
2. Never ship the service-role / secret key to the browser.
3. Backfill data **before** enabling RLS, or you lock everyone out.
4. Roles live on the membership, not the user.
5. One feature-gating helper, checked on client (UX) **and** server (enforcement).
6. Billing state is driven by **verified webhooks**, not the checkout redirect.

## License

MIT © Dolev Hayut
