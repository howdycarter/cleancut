-- Enhancements: track email, product id, and last event for subscriptions
alter table if exists public.user_subscriptions
  add column if not exists email text,
  add column if not exists product_id text,
  add column if not exists last_event text;

-- Helpful indexes for lookups
create index if not exists idx_user_subscriptions_email on public.user_subscriptions (email);
create index if not exists idx_user_subscriptions_updated_at on public.user_subscriptions (updated_at);

-- Enable RLS and allow users to read their own row
alter table if exists public.user_subscriptions enable row level security;
do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'user_subscriptions' and policyname = 'Users can read their own subscription'
  ) then
    create policy "Users can read their own subscription" on public.user_subscriptions
      for select using (user_id = auth.uid());
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'user_subscriptions' and policyname = 'Users can insert their own subscription'
  ) then
    create policy "Users can insert their own subscription" on public.user_subscriptions
      for insert with check (user_id = auth.uid());
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'user_subscriptions' and policyname = 'Users can update their own subscription'
  ) then
    create policy "Users can update their own subscription" on public.user_subscriptions
      for update using (user_id = auth.uid());
  end if;
end $$;
