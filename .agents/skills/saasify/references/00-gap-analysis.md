# Step 1 — Gap Analysis & Detection

Goal: understand the project before changing anything, then produce a Gap Report the user can confirm.

## Detect the stack

Run these checks (adapt to what you find):

```bash
# Framework & deps
cat package.json | grep -E '"(next|react|vite|@supabase|firebase|prisma|drizzle|next-auth|@clerk|stripe)"'

# Next.js App Router vs Pages vs Vite SPA
ls -d app src/app pages src/pages 2>/dev/null
ls next.config.* vite.config.* 2>/dev/null

# Existing backend / DB
ls supabase/ prisma/ drizzle/ 2>/dev/null
find . -path ./node_modules -prune -o -name '*.sql' -print 2>/dev/null | head
grep -rl "createClient" src 2>/dev/null | head      # supabase client
```

## Map to the decision matrix

| Detected | Auth approach | Tenancy enforcement | Billing fit |
|----------|---------------|---------------------|-------------|
| Supabase | Supabase Auth (default) | **RLS policies** + `organization_id` | Stripe / HYP via Edge Functions |
| Next.js + Drizzle/Prisma + Postgres | NextAuth v5 or Supabase Auth | query-layer tenant guard or RLS | Stripe (native), webhooks in route handlers |
| Vite/React SPA + Supabase | `AuthContext` + protected routes | RLS (frontend can't be trusted) | Edge Function + redirect to gateway |
| Firebase | Firebase Auth | Firestore security rules | Stripe / RevenueCat |
| No backend yet | **Add Supabase first** | — | — |

If there's no backend at all, propose adding Supabase as Step 0 — it's the fastest path to all four pillars.

## Detect what already exists (per pillar)

- **Auth** — look for: login/signup pages, `supabase.auth`, `next-auth`, `@clerk`, a `session`/`useUser` hook, a `users`/`profiles` table.
- **Multi-tenancy** — look for: an `organization`/`org`/`team`/`workspace`/`tenant`/`account` table, an `organization_id`/`team_id` foreign key on domain tables, RLS policies, an org-switcher in the UI.
- **RBAC** — look for: a `role` column, a `members`/`memberships` junction table, `is_admin()`, permission checks, route guards by role.
- **Billing** — look for: `stripe`, `hyp`/`tranzila`/`sumit`, a `subscriptions`/`plans`/`licenses`/`payments` table, a pricing page, webhook handlers, plan-gating code.

## Identify tenant-scoped entities

List the project's core domain tables (e.g. `tasks`, `customers`, `posts`, `events`). These are the rows that must become tenant-scoped in Step 3. Note which already have an owner/user column vs none.

## Produce the Gap Report

Output a compact table, then proceed to Step 2 (AskUserQuestion):

```
SaaS Gap Report — <project name>
Stack: <e.g. Vite + React + Supabase>
Core entities to scope: <tasks, clients, invoices, ...>

Pillar            Status   Notes
Authentication    🟡       Supabase client exists, no login page
Multi-tenancy     ❌       no org concept; tables are global
RBAC              ❌       no roles
Plans & Billing   ❌       none

Recommended: add org-based tenancy + Supabase Auth + 3-tier plans (Free/Pro/Business) with Stripe (+ HYP if Israeli market).
```

Status legend: ✅ exists & solid · 🟡 partial · ❌ missing.
