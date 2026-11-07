# Pillar 1 — Authentication

The foundation. Nothing else (tenancy, roles, billing) works without knowing *who* the user is. Default to **Supabase Auth** for this stack.

## Decision: which provider

- **Supabase Auth** — default. Email/password + Google OAuth, free, integrates with RLS via `auth.uid()`/`auth.jwt()`. Use this unless something else already exists.
- **NextAuth v5 (Auth.js)** — if the project is Next.js + Drizzle/Prisma without Supabase (e.g. the maximbot/metrobot/Ticket-Amarel pattern). Supports credentials + OAuth; you own the `users` table.
- **Clerk** — if already installed or the user wants drop-in orgs+UI.

Don't introduce a second auth system if one exists — extend it.

## A. Supabase Auth — Vite/React SPA

**1. Client singleton** (`src/integrations/supabase/client.ts` or `src/lib/supabase.ts`):
```ts
import { createClient } from '@supabase/supabase-js'
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL!,
  import.meta.env.VITE_SUPABASE_ANON_KEY!,   // anon key only — NEVER the service_role key in the client
)
```

**2. AuthContext** (`src/contexts/AuthContext.tsx`) — the canonical pattern across these projects:
```tsx
import { createContext, useContext, useEffect, useState } from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'

type AuthCtx = { user: User | null; session: Session | null; loading: boolean
  signIn: (e: string, p: string) => Promise<{ error: Error | null }>
  signUp: (e: string, p: string) => Promise<{ error: Error | null }>
  signInWithGoogle: () => Promise<void>; signOut: () => Promise<void> }

const Ctx = createContext<AuthCtx | undefined>(undefined)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => { setSession(data.session); setUser(data.session?.user ?? null); setLoading(false) })
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => { setSession(s); setUser(s?.user ?? null) })
    return () => sub.subscription.unsubscribe()
  }, [])

  const value: AuthCtx = {
    user, session, loading,
    signIn: (email, password) => supabase.auth.signInWithPassword({ email, password }).then(r => ({ error: r.error })),
    signUp: (email, password) => supabase.auth.signUp({ email, password }).then(r => ({ error: r.error })),
    signInWithGoogle: async () => { await supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: `${location.origin}/auth/callback` } }) },
    signOut: async () => { await supabase.auth.signOut() },
  }
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}
export const useAuth = () => { const c = useContext(Ctx); if (!c) throw new Error('useAuth outside AuthProvider'); return c }
```

**3. Protected route** wrapper:
```tsx
export function RequireAuth({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth()
  if (loading) return <FullPageSpinner />
  if (!user) return <Navigate to="/login" replace />
  return <>{children}</>
}
```

**4. Pages to create**: `/login`, `/signup`, `/reset-password`, `/update-password`, `/auth/callback`. Include: email+password form, Google button, password-strength hint on signup, friendly (localized) error messages.

## B. Supabase Auth — Next.js App Router (SSR)

This is the mettrico-next pattern. Use `@supabase/ssr`.

**Middleware** (`middleware.ts`) — refreshes session and guards routes:
```ts
import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(req: NextRequest) {
  let res = NextResponse.next({ request: req })
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: {
      getAll: () => req.cookies.getAll(),
      setAll: (c) => { c.forEach(({ name, value, options }) => res.cookies.set(name, value, options)) },
    } },
  )
  const { data: { user } } = await supabase.auth.getUser()
  const path = req.nextUrl.pathname
  const isPublic = ['/login', '/signup', '/reset-password', '/auth'].some(p => path.startsWith(p))
  if (!user && !isPublic && !path.startsWith('/_next')) return NextResponse.redirect(new URL('/login', req.url))
  return res
}
export const config = { matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg)$).*)'] }
```
Provide `lib/supabase/server.ts` (server client) and `lib/supabase/client.ts` (browser client) per the `@supabase/ssr` docs. Use Context7 MCP (`@supabase/ssr`) to pull the current exact API if unsure.

## C. NextAuth v5 (no Supabase)

If Drizzle/Prisma + Postgres: define a `users` table with hashed password (bcrypt), configure `auth.ts` with Credentials + OAuth providers, and an `(auth)` route group for login/register. After auth works, tenancy/roles attach to the same `users` table. (maximbot/Ticket-Amarel pattern.)

## After auth: the `profiles` table

Supabase's `auth.users` is private. Create a public mirror so you can join and store app data:
```sql
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text, full_name text, avatar_url text,
  created_at timestamptz default now()
);
alter table public.profiles enable row level security;
create policy "own profile" on public.profiles for all using (auth.uid() = id);

-- auto-create profile on signup
create function public.handle_new_user() returns trigger language plpgsql security definer as $$
begin insert into public.profiles (id, email) values (new.id, new.email); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
```

## Verify
- [ ] Sign up → row appears in `auth.users` and `profiles`
- [ ] Sign in → session persists across reload
- [ ] Unauthenticated user is redirected from protected routes
- [ ] Sign out clears session
- [ ] Only the **anon** key is in client code (grep for `service_role`)
