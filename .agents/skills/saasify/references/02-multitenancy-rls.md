# Pillar 2 — Multi-tenancy (the heart of SaaS)

"Each customer sees only their own data." This MUST be enforced at the database, never the UI. The proven pattern: an `organizations` table, an `organization_id` column on every tenant-scoped table, and **RLS policies** backed by helper functions.

## Choose the tenancy model (confirm in Step 2)

- **Personal / user-scoped** — simplest. Data belongs to a `user_id`. Good for solo-user SaaS (notes, personal dashboards). Scope by `auth.uid()`.
- **Organization / B2B** — data belongs to an `organization_id`; users join orgs via a membership table; one user can belong to many orgs. This is the real "team SaaS" model. **Default for B2B.**
- **Hybrid** — personal workspace + shareable orgs.

The rest of this file covers the **organization** model (downgrade to user-scoped by replacing `organization_id` with `user_id` and dropping the membership layer).

## Core schema

```sql
-- 1. Organizations (tenants)
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  plan text not null default 'free',          -- ties into billing (pillar 4)
  created_at timestamptz default now()
);

-- 2. Membership junction (role lives HERE, not on the user)
create type org_role as enum ('owner', 'admin', 'member');
create table public.organization_members (
  organization_id uuid references public.organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role org_role not null default 'member',
  created_at timestamptz default now(),
  primary key (organization_id, user_id)
);
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
```

## Helper functions (the dyno-crm pattern — reuse everywhere)

These run as `security definer` so they can read membership without recursive RLS. They are the backbone of every policy.

```sql
-- All org IDs the current user belongs to
create or replace function public.user_org_ids()
returns setof uuid language sql security definer stable as $$
  select organization_id from public.organization_members where user_id = auth.uid()
$$;

-- Is the current user an admin/owner of a given org?
create or replace function public.is_org_admin(org uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.organization_members
    where organization_id = org and user_id = auth.uid() and role in ('owner','admin')
  )
$$;
```

## Policies on the org tables

```sql
-- Members can see orgs they belong to
create policy "read own orgs" on public.organizations
  for select using (id in (select public.user_org_ids()));

-- Only admins/owners can update the org
create policy "admins update org" on public.organizations
  for update using (public.is_org_admin(id));

-- Members can see co-members; admins manage membership
create policy "read members" on public.organization_members
  for select using (organization_id in (select public.user_org_ids()));
create policy "admins manage members" on public.organization_members
  for all using (public.is_org_admin(organization_id));
```

## Scope every domain table (the repeatable recipe)

For EACH tenant-scoped entity (`tasks`, `customers`, `invoices`, …):

```sql
-- 1. add the tenant column
alter table public.tasks add column organization_id uuid references public.organizations(id) on delete cascade;

-- 2. enable RLS
alter table public.tasks enable row level security;

-- 3. one policy per operation (or a single FOR ALL)
create policy "tenant read"   on public.tasks for select using (organization_id in (select public.user_org_ids()));
create policy "tenant insert" on public.tasks for insert with check (organization_id in (select public.user_org_ids()));
create policy "tenant update" on public.tasks for update using (organization_id in (select public.user_org_ids()));
create policy "tenant delete" on public.tasks for delete using (organization_id in (select public.user_org_ids()));

-- 4. index it — every tenant query filters on this column
create index on public.tasks (organization_id);
```

> Tip: `with check` on insert/update prevents a user from writing rows into an org they don't belong to. Always include it.

## ⚠️ Backfill BEFORE enforcing (critical — don't lock people out)

When adding `organization_id` to a table that already has data:

```sql
-- 1. create a default org and make existing users members
-- 2. backfill existing rows (e.g. via the row's existing user_id → that user's org)
update public.tasks t set organization_id = m.organization_id
  from public.organization_members m where t.user_id = m.user_id and t.organization_id is null;
-- 3. only AFTER backfill: set NOT NULL and enable the policies
alter table public.tasks alter column organization_id set not null;
```
Order matters: backfill → NOT NULL → RLS. Reverse it and existing data becomes invisible.

## Frontend: the active-org context

Users with multiple orgs need an org switcher. Pattern (mettrico-next `OrganizationContext`):
```tsx
// fetch user's orgs from organization_members ⋈ organizations
// store activeOrgId in localStorage; expose { orgs, activeOrg, setActiveOrg }
// new user with zero orgs → redirect to /onboarding (create first org)
```
All tenant queries then run within the active org. RLS is the real guard, but the context drives which org's data the UI requests and provides the org switcher.

## Non-Supabase equivalents

- **Prisma/Drizzle + Postgres**: either enable Postgres RLS with `SET app.current_org` per request, OR enforce a **tenant guard in the data layer** — a wrapper that injects `where organizationId = ctx.orgId` on every query and rejects queries without it. Never rely on each call site remembering.
- **Firebase**: Firestore security rules keyed on a membership doc.

The principle is identical everywhere: **the tenant filter is mandatory and centralized, never per-component.**

## Verify (do this — it's the #1 SaaS security bug)
- [ ] Log in as user A (org 1), create a row. Log in as user B (org 2) — confirm B **cannot** read/update/delete A's row, via the API directly (not just the UI).
- [ ] Every tenant table has RLS enabled AND at least one policy (a table with RLS on but no policy = nobody can read it).
- [ ] `organization_id` is `NOT NULL` and indexed on every tenant table.
- [ ] Inserts can't target a foreign org (the `with check`).
