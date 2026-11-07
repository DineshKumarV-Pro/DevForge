# Pillar 3 — RBAC (roles & permissions)

Control *what* a user can do inside their org. The role lives on the **membership**, not the user — the same person can be `owner` of one org and `member` of another.

## Pick the right granularity

Don't over-engineer. Three tiers cover ~90% of SaaS:

| Model | Roles | When |
|-------|-------|------|
| **Simple** (default) | `owner`, `admin`, `member` | most B2B SaaS |
| **Read-tier** | + `viewer` / `guest` | when read-only sharing matters |
| **Hierarchical** | e.g. `system_admin > general_manager > department_manager > team_manager > agent` | enterprise / org-chart products (commission360 pattern) — adds department/team scoping on top of org scoping |

Start simple; escalate only if the domain demands it.

## Where roles are enforced (defense in depth)

1. **Database (authoritative)** — RLS policies branch on role via the `is_org_admin()` helper from pillar 2. This is the real guard.
2. **Server/API** — re-check before mutations (don't trust the client).
3. **UI (UX only)** — hide/disable buttons the user can't use. Never the *only* check.

## Database-level role checks

Extend the membership helpers (built in pillar 2):
```sql
-- exact-role check
create or replace function public.has_org_role(org uuid, roles org_role[])
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.organization_members
    where organization_id = org and user_id = auth.uid() and role = any(roles)
  )
$$;
```
Use it in policies that need finer control than admin/member:
```sql
-- only owners can delete the organization
create policy "owner deletes org" on public.organizations
  for delete using (public.has_org_role(id, array['owner']::org_role[]));

-- members create tasks, but only admins can delete them
create policy "admin deletes task" on public.tasks
  for delete using (public.is_org_admin(organization_id));
```

## Hierarchical / department scoping (when needed)

The commission360 pattern stores department/team on the membership and reads JWT claims in policies:
```sql
alter table public.organization_members add column department text, add column team text;

-- a department_manager sees only their department's rows
create policy "dept scope" on public.deals for select using (
  organization_id in (select public.user_org_ids())
  and (
    public.is_org_admin(organization_id)                      -- admins see all
    or department = (auth.jwt() ->> 'department')             -- managers see their dept
    or owner_id = auth.uid()                                  -- everyone sees their own
  )
);
```

## Client-side permission helper

One place, checked everywhere — don't scatter `role === 'admin'` across components:
```ts
// permissions.ts
export type Role = 'owner' | 'admin' | 'member'
const RANK: Record<Role, number> = { owner: 3, admin: 2, member: 1 }
export const atLeast = (role: Role, min: Role) => RANK[role] >= RANK[min]

export const can = {
  manageBilling:  (r: Role) => atLeast(r, 'owner'),
  inviteMembers:  (r: Role) => atLeast(r, 'admin'),
  deleteOrg:      (r: Role) => r === 'owner',
  editSettings:   (r: Role) => atLeast(r, 'admin'),
  createContent:  (r: Role) => atLeast(r, 'member'),
}
```
```tsx
const { role } = useActiveOrg()
{can.inviteMembers(role) && <InviteButton />}
```

## Route guard by role (Next.js / React)
```tsx
export function RequireRole({ min, children }: { min: Role; children: React.ReactNode }) {
  const { role } = useActiveOrg()
  if (!atLeast(role, min)) return <Forbidden />
  return <>{children}</>
}
```

## Verify
- [ ] A `member` cannot hit an admin-only mutation even by calling the API directly (RLS/role check blocks it, not just a hidden button).
- [ ] Role is read from `organization_members`, scoped to the **active** org.
- [ ] Owner-only actions (delete org, manage billing) are gated.
- [ ] The first user who creates an org becomes `owner` automatically.
