-- Migration 005: AI health coach chat history
-- Stores the conversation so it survives app restarts and device changes.

create table if not exists public.coach_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('user', 'model')),
  text text not null check (char_length(text) <= 4000),
  -- Meal cards attached to a coach reply. Empty array for user turns.
  suggestions jsonb not null default '[]'::jsonb
    check (jsonb_typeof(suggestions) = 'array' and jsonb_array_length(suggestions) <= 5),
  created_at timestamptz not null default now()
);

create index if not exists coach_messages_user_created_idx
  on public.coach_messages (user_id, created_at desc);

alter table public.coach_messages enable row level security;

-- Read-only for the owner. Writes happen in the chat-health-coach Edge
-- Function with the service role, so a client cannot forge a coach reply
-- and cannot rewrite history to steer later turns.
drop policy if exists coach_messages_select on public.coach_messages;
create policy coach_messages_select on public.coach_messages
  for select using (user_id = auth.uid());

-- Clearing your own chat is a normal user action, so delete stays client-side.
drop policy if exists coach_messages_delete on public.coach_messages;
create policy coach_messages_delete on public.coach_messages
  for delete using (user_id = auth.uid());

revoke insert, update on public.coach_messages from authenticated, anon;
grant all on public.coach_messages to service_role;
