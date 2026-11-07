# Step 4 — Final Verification & Hardening Checklist

Run this after building. The starred (★) items are the ones that, if wrong, make the SaaS insecure or unusable — verify them by actually testing, not by reading code.

## Security (most important)
- [ ] ★ **Cross-tenant isolation**: as user B in org 2, you CANNOT read/update/delete org 1's data — tested against the API directly, not just the UI.
- [ ] ★ **No service-role / secret keys in the client bundle**: `grep -rn "service_role\|sk_live\|sk_test\|SUPABASE_SERVICE" src/ app/` returns nothing client-side.
- [ ] ★ Every tenant-scoped table has RLS **enabled** AND at least one policy.
- [ ] Insert/update policies use `with check` so users can't write into other orgs.
- [ ] Webhooks (Stripe/HYP) **verify signatures** and run server-side only.
- [ ] Role checks are enforced server-side/RLS, not only by hidden buttons.
- [ ] Secrets are in env vars, not committed. `.env.example` documents required keys.

## Auth
- [ ] Signup → profile row auto-created → can sign in → session persists → sign out works.
- [ ] Protected routes redirect unauthenticated users; OAuth callback works.
- [ ] Password reset flow works end to end.

## Multi-tenancy
- [ ] `organization_id` is `NOT NULL` + indexed on every tenant table.
- [ ] Existing data was backfilled BEFORE RLS was enforced (no one locked out).
- [ ] Org switcher works for users in multiple orgs; queries scope to active org.

## RBAC
- [ ] First org creator is `owner`. Roles read from `organization_members` per active org.
- [ ] A `member` is blocked from admin/owner actions at the API level.
- [ ] Owner-only actions (delete org, manage billing) gated.

## Plans & Billing
- [ ] Plan catalog is the single source of truth; `org.plan` mirrors real subscription state.
- [ ] Feature gates + usage limits enforced server-side.
- [ ] Upgrade, downgrade, cancel all sync correctly via webhook; cancel reverts to `free`.
- [ ] (Israeli) amounts in ₪, invoice issued, recurring token stored, server-side verified.
- [ ] Pricing page + billing/settings page exist and reflect current state.

## Invites & onboarding
- [ ] New user with no org → onboarding → becomes owner of a new org.
- [ ] Invite link works; expired/revoked tokens rejected; seat limit enforced.

## Build & regression
- [ ] Project builds/compiles; types pass.
- [ ] Pre-existing features still work, now scoped to the tenant.
- [ ] Migrations run cleanly on a fresh DB (idempotent / ordered).

## Don't forget (commonly missed)
- [ ] Localization (Hebrew/RTL) for auth errors, plan names, invite emails if the audience needs it.
- [ ] Empty/zero states (no orgs, no members, trial expired).
- [ ] An audit log for sensitive actions (role changes, billing, deletions) if compliance matters.
