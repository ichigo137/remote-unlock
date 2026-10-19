create table if not exists public.remoteunlock_commands (
  id uuid primary key default gen_random_uuid(),
  action text not null check (action = 'lock'),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  claimed_at timestamptz
);

create index if not exists remoteunlock_commands_pending_idx
  on public.remoteunlock_commands (created_at)
  where claimed_at is null;

alter table public.remoteunlock_commands enable row level security;

-- Only the Edge Function's server-side service key may access the queue.
revoke all on table public.remoteunlock_commands from anon, authenticated;
grant all on table public.remoteunlock_commands to service_role;
