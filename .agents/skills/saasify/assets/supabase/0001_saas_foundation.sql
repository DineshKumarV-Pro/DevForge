-- ============================================================================
-- SaaS Foundation Migration (Supabase / Postgres)
-- Organizations + memberships + roles + RLS helpers + invites.
-- Adapt table/column names to the project. Run AFTER auth is set up.
-- Domain tables (tasks/customers/etc.) are scoped separately — see the
-- "scope a domain table" block at the bottom; repeat it per entity.
-- ============================================================================

-- ---------- Enums ----------
do $$ begin create type org_role as enum ('owner','admin','member'); exception when duplicate_object then null; end $$;
do $$ begin create type invite_status as enum ('pending','accepted','expired','revoked'); exception when duplicate_object then null; end $$;

-- ---------- Profiles (public mirror of auth.users) ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text, full_name text, avatar_url text,
  created_at timestamptz default now()
);
alter table public.profiles enable row level security;
drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles for all using (auth.uid() = id);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer as $$
begin insert into public.profiles (id, email) values (new.id, new.email) on conflict do nothing; return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- ---------- Organizations (tenants) ----------
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  plan text not null default 'free',
  credit_balance integer not null default 0,
  created_at timestamptz default now()
);

create table if not exists public.organization_members (
  organization_id uuid references public.organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role org_role not null default 'member',
  department text, team text,
  created_at timestamptz default now(),
  primary key (organization_id, user_id)
);

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;

-- ---------- Helper functions (security definer to avoid recursive RLS) ----------
create or replace function public.user_org_ids()
returns setof uuid language sql security definer stable as $$
  select organization_id from public.organization_members where user_id = auth.uid()
$$;

create or replace function public.is_org_admin(org uuid)
returns boolean language sql security definer stable as $$
  select exists (select 1 from public.organization_members
    where organization_id = org and user_id = auth.uid() and role in ('owner','admin'))
$$;

create or replace function public.has_org_role(org uuid, roles org_role[])
returns boolean language sql security definer stable as $$
  select exists (select 1 from public.organization_members
    where organization_id = org and user_id = auth.uid() and role = any(roles))
$$;

-- ---------- Org policies ----------
drop policy if exists "read own orgs" on public.organizations;
create policy "read own orgs" on public.organizations for select using (id in (select public.user_org_ids()));
drop policy if exists "admins update org" on public.organizations;
create policy "admins update org" on public.organizations for update using (public.is_org_admin(id));
drop policy if exists "owner deletes org" on public.organizations;
create policy "owner deletes org" on public.organizations for delete using (public.has_org_role(id, array['owner']::org_role[]));

drop policy if exists "read members" on public.organization_members;
create policy "read members" on public.organization_members for select using (organization_id in (select public.user_org_ids()));
drop policy if exists "admins manage members" on public.organization_members;
create policy "admins manage members" on public.organization_members for all using (public.is_org_admin(organization_id));

-- ---------- Create-org-with-owner (used by onboarding) ----------
create or replace function public.create_org_with_owner(org_name text)
returns uuid language plpgsql security definer as $$
declare new_org uuid;
begin
  insert into public.organizations(name) values (org_name) returning id into new_org;
  insert into public.organization_members(organization_id, user_id, role) values (new_org, auth.uid(), 'owner');
  return new_org;
end; $$;

-- ---------- Subscriptions (billing state; written by webhooks/service role) ----------
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plan text not null default 'free',
  status text not null default 'active',
  provider text not null default 'manual',
  provider_customer_id text, provider_subscription_id text,
  current_period_end timestamptz, trial_ends_at timestamptz,
  created_at timestamptz default now()
);
alter table public.subscriptions enable row level security;
drop policy if exists "members read sub" on public.subscriptions;
create policy "members read sub" on public.subscriptions for select using (organization_id in (select public.user_org_ids()));

-- ---------- Invites ----------
create table if not exists public.invites (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  email text not null,
  role org_role not null default 'member',
  token text unique not null default encode(gen_random_bytes(24),'hex'),
  status invite_status not null default 'pending',
  invited_by uuid references auth.users(id),
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz default now()
);
alter table public.invites enable row level security;
drop policy if exists "admins manage invites" on public.invites;
create policy "admins manage invites" on public.invites for all using (public.is_org_admin(organization_id));

-- ---------- Usage metering (optional) ----------
create table if not exists public.usage_logs (
  organization_id uuid references public.organizations(id) on delete cascade,
  amount integer, reason text, created_at timestamptz default now()
);
create or replace function public.deduct_credits(org uuid, amt int, why text)
returns int language plpgsql security definer as $$
declare remaining int;
begin
  update public.organizations set credit_balance = credit_balance - amt
    where id = org and credit_balance >= amt returning credit_balance into remaining;
  if remaining is null then raise exception 'INSUFFICIENT_CREDITS'; end if;
  insert into public.usage_logs(organization_id, amount, reason) values (org, amt, why);
  return remaining;
end; $$;

-- ============================================================================
-- TEMPLATE: scope a domain table to the tenant. Copy/paste per entity.
-- Replace `tasks` with the real table name.
-- ============================================================================
-- alter table public.tasks add column if not exists organization_id uuid references public.organizations(id) on delete cascade;
-- -- BACKFILL existing rows here BEFORE the NOT NULL + policies (see references/02).
-- -- alter table public.tasks alter column organization_id set not null;
-- create index if not exists tasks_org_idx on public.tasks (organization_id);
-- alter table public.tasks enable row level security;
-- create policy "tenant read"   on public.tasks for select using (organization_id in (select public.user_org_ids()));
-- create policy "tenant insert" on public.tasks for insert with check (organization_id in (select public.user_org_ids()));
-- create policy "tenant update" on public.tasks for update using (organization_id in (select public.user_org_ids()));
-- create policy "tenant delete" on public.tasks for delete using (organization_id in (select public.user_org_ids()));
