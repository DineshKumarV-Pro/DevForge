# Pillar 4 — Plans & Billing

Turn the product into a business: define **plans/tiers**, charge for them, and **gate features** by what the org pays for. This is what makes it a SaaS and not just a multi-user app.

## Step A — Define the plan catalog (do this first, always)

Even before choosing a gateway, define tiers as data so the whole app can reason about them. Single source of truth:

```ts
// plans.ts — the catalog
export type PlanId = 'free' | 'pro' | 'business'

export const PLANS = {
  free:     { id: 'free',     name: 'Free',     priceMonthly: 0,
              limits: { seats: 1,  projects: 3,   storageMb: 100 },
              features: { exports: false, api: false, sso: false } },
  pro:      { id: 'pro',      name: 'Pro',      priceMonthly: 29,
              limits: { seats: 5,  projects: 50,  storageMb: 5000 },
              features: { exports: true,  api: true,  sso: false } },
  business: { id: 'business', name: 'Business', priceMonthly: 99,
              limits: { seats: 25, projects: -1,  storageMb: 50000 }, // -1 = unlimited
              features: { exports: true,  api: true,  sso: true } },
} as const

export const can = (plan: PlanId, feature: keyof typeof PLANS.free.features) => PLANS[plan].features[feature]
export const withinLimit = (plan: PlanId, key: keyof typeof PLANS.free.limits, current: number) => {
  const max = PLANS[plan].limits[key]; return max === -1 || current < max
}
```

Persist the org's current plan on `organizations.plan` (already added in pillar 2) and mirror subscription state:
```sql
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plan text not null default 'free',
  status text not null default 'active',   -- active | trialing | past_due | canceled
  provider text not null,                  -- 'stripe' | 'hyp' | 'gumroad' | 'manual'
  provider_customer_id text,
  provider_subscription_id text,
  current_period_end timestamptz,
  trial_ends_at timestamptz,
  created_at timestamptz default now()
);
alter table public.subscriptions enable row level security;
create policy "members read sub" on public.subscriptions for select using (organization_id in (select public.user_org_ids()));
-- writes happen via service role in webhooks only — no client write policy
```

## Step B — Choose the gateway (confirm in Step 2)

| Gateway | Use when | Model |
|---------|----------|-------|
| **Stripe** | global, cards, real subscriptions | Checkout + Billing Portal + webhooks |
| **HYP / היפ** (sumit / tranzila) | **Israeli market** — local cards, חשבוניות, תשלומים | hosted payment page + redirect + server confirmation |
| **Gumroad** | one-off **license keys**, no recurring infra | webhook on sale → issue license |
| **Usage / credits** | metered AI / API products | balance + `deduct_credits` RPC |

You can combine (e.g. Stripe for global + HYP for Israel).

---

## Stripe (international subscriptions)

**Checkout** (server / Edge Function — never client):
```ts
const session = await stripe.checkout.sessions.create({
  mode: 'subscription',
  line_items: [{ price: PRICE_ID[planId], quantity: 1 }],
  success_url: `${origin}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
  cancel_url: `${origin}/billing`,
  client_reference_id: organizationId,           // ← map back to the tenant
  customer: existingCustomerId,                  // reuse if known
})
return { url: session.url }
```

**Webhook is the source of truth** — update the DB here, not on the redirect:
```ts
// verify signature, then handle:
//  checkout.session.completed        → set plan + provider_subscription_id, status 'active'
//  customer.subscription.updated     → sync status & current_period_end
//  customer.subscription.deleted     → status 'canceled', revert org.plan to 'free'
//  invoice.payment_failed            → status 'past_due'
const event = stripe.webhooks.constructEvent(rawBody, sig, WEBHOOK_SECRET) // ALWAYS verify
```
**Billing Portal** for self-serve upgrades/cancels: `stripe.billingPortal.sessions.create({ customer, return_url })`.

> Use Context7 MCP (`stripe` / `@stripe/stripe-js`) for the current exact API and event names before writing — they evolve.

---

## HYP / היפ (Israeli payments — the project-3 / door-sign pattern)

Israeli gateways (HYP/יד2 sumit, Tranzila, Meshulam) use a **hosted page + redirect + server-side verification** flow rather than Stripe's SDK. Generic shape:

```ts
// 1. server creates a payment request → returns a redirect URL to the hosted page
//    params: terminal/masof id, amount, currency=ILS, order id = organizationId,
//    success/cancel/notification (server-to-server) URLs, customer details, recurring flag for הוראת קבע
// 2. redirect the user to that URL
// 3. gateway calls your server NOTIFICATION url (server-to-server) with the result
//    → verify the transaction against the gateway API, then update subscriptions + org.plan
// 4. user is redirected back to success_url (treat as UX only; trust the server notification)
```
Key differences vs Stripe to handle:
- Amounts in **ILS (₪)**, often agorot precision; produce a **חשבונית מס/קבלה** (tax invoice) — many Israeli gateways (sumit) issue it automatically.
- **Recurring = הוראת קבע / תשלום חוזר** — a separate flag/endpoint, not Stripe-style subscription objects. Store the token they return.
- **Trial period** (project-3 `TrialPeriodBanner`): set `trial_ends_at`, show a banner, block charging until trial ends, then create the recurring charge.
- Always **verify server-side** — the redirect can be spoofed; the server-to-server notification + a verification API call is the trusted signal.

Confirm the exact gateway (HYP, Tranzila, Sumit, Meshulam, Cardcom) with the user and fetch its current API docs before implementing — each differs.

---

## License keys (Gumroad — the license-hub pattern)

For products sold once (or per-seat) without recurring infra:
```sql
create table public.licenses (
  id uuid primary key default gen_random_uuid(),
  key text unique not null,
  tier text not null,                 -- personal | agency | ...
  status text not null default 'active',  -- unused | active | revoked
  organization_id uuid references public.organizations(id),
  provider_order_id text,             -- Gumroad/Stripe order id
  created_at timestamptz default now()
);
create table public.license_activations (
  license_id uuid references public.licenses(id) on delete cascade,
  domain text, ip text, activated_at timestamptz default now()
);
-- writes by service_role only; clients verify a key via an Edge Function
```
Webhook on sale → generate key → email it. A `verify-license` Edge Function checks key + records activation (domain/IP) and enforces the tier/seat cap.

---

## Usage metering / credits (owly-agents pattern)

For AI/API products billed by consumption:
```sql
alter table public.organizations add column credit_balance integer not null default 0;
create table public.usage_logs (
  organization_id uuid references public.organizations(id),
  amount integer, reason text, created_at timestamptz default now()
);
-- atomic deduction so concurrent calls can't overspend
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
```
Top-ups buy credits via Stripe/HYP one-time payments.

---

## Step C — Gate features by plan (enforce everywhere)

The whole point of plans. Check in two places:

**Server / RLS** (authoritative) — e.g. block creating a 4th project on Free:
```sql
create policy "project quota" on public.projects for insert with check (
  organization_id in (select public.user_org_ids())
  and (
    (select plan from public.organizations where id = organization_id) <> 'free'
    or (select count(*) from public.projects where organization_id = projects.organization_id) < 3
  )
);
```
**Client** (UX) — disable + show upgrade prompt:
```tsx
const { plan } = useActiveOrg()
{!can(plan, 'exports') && <UpgradePrompt feature="exports" />}
{can(plan, 'exports') ? <ExportButton/> : <LockedButton onClick={goToBilling}/>}
```

## Pricing & billing UI to build
- `/pricing` — plan comparison cards (highlight recommended), monthly/yearly toggle.
- `/billing` (or settings) — current plan, usage vs limits, upgrade/downgrade, manage payment (Stripe portal / HYP), invoice history.
- Upgrade prompts at the point of friction (hit a limit → "Upgrade to Pro").
- Trial banner if trials are used.

## Verify
- [ ] Plan catalog is a single source of truth; `org.plan` reflects real subscription state.
- [ ] Feature gates enforced **server-side**, not only hidden in the UI.
- [ ] Webhooks verify signatures and are the source of truth for plan changes.
- [ ] Downgrade/cancel reverts `org.plan` to `free` and re-applies limits.
- [ ] No secret keys (Stripe secret, HYP terminal creds) in the client bundle.
- [ ] Israeli flow: amounts in ₪, invoice issued, recurring token stored, server-side verification.
