-- Creates the user_subscriptions table to mirror RevenueCat via webhook
create table if not exists public.user_subscriptions (
  user_id uuid references auth.users on delete cascade,
  plan text check (plan in ('free','pro','premium')) default 'free',
  expires_at timestamptz,
  updated_at timestamptz default now(),
  primary key (user_id)
);

