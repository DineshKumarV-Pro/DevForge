# Pillar 5 — Invites & Onboarding (the connective tissue)

Auth + tenancy + roles + billing only become a usable product when new users can get *in* and existing teams can *grow*. Two flows: **first-run onboarding** (a brand-new signup) and **invites** (adding people to an existing org).

## First-run onboarding

A user who just signed up has no org. Flow:
1. After signup, check membership: `select * from organization_members where user_id = auth.uid()`.
2. If **zero orgs** → redirect to `/onboarding`.
3. Onboarding creates the first org and makes the user its **owner**:
```sql
create or replace function public.create_org_with_owner(org_name text)
returns uuid language plpgsql security definer as $$
declare new_org uuid;
begin
  insert into public.organizations(name) values (org_name) returning id into new_org;
  insert into public.organization_members(organization_id, user_id, role)
    values (new_org, auth.uid(), 'owner');
  return new_org;
end; $$;
```
4. Set it as the active org (pillar 2 context) → land in the app on the `free` plan.

Keep onboarding short: org name (+ optional logo/slug), maybe an "invite teammates" step, done.

## Invite flow (grow the org)

The dyno-crm / mettrico-next pattern: token + email + role + expiry + status.

```sql
create type invite_status as enum ('pending', 'accepted', 'expired', 'revoked');
create table public.invites (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  email text not null,
  role org_role not null default 'member',
  token text unique not null default encode(gen_random_bytes(24), 'hex'),
  status invite_status not null default 'pending',
  invited_by uuid references auth.users(id),
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz default now()
);
alter table public.invites enable row level security;
-- admins of the org manage invites
create policy "admins manage invites" on public.invites
  for all using (public.is_org_admin(organization_id));
```

**Send** (admin action): insert an invite, then email the link `/invite/accept?token=...` (Resend / Supabase email / your provider). Respect the seat limit of the org's plan before allowing the invite (pillar 4).

**Accept** (Edge Function / server route, runs as service role after auth):
```ts
// 1. require the visitor to be signed in (or sign up) with the invited email
// 2. load invite by token; reject if status != 'pending' or expires_at < now()
// 3. insert into organization_members (organization_id, user_id, role)
// 4. mark invite status = 'accepted'
// 5. set the new org as active → land them in the app
```

**Lifecycle**: a daily job (or check-on-read) flips `pending` invites past `expires_at` to `expired`. Admins can `revoke` (set status, the token stops working).

## Member management UI (settings → members)
- List members with role + joined date.
- Invite by email + role picker (gated by seat limit & `can.inviteMembers`).
- Change role / remove member (owner/admin only; can't remove the last owner).
- Pending invites list with resend / revoke.

## Verify
- [ ] New signup with no org lands in onboarding and creates an org as owner.
- [ ] Invite email delivers a working tokened link.
- [ ] Expired/revoked/already-accepted tokens are rejected.
- [ ] Accepting adds the user to the correct org with the correct role.
- [ ] Seat limits from the plan are enforced before inviting.
- [ ] The last owner of an org cannot be removed/demoted.
