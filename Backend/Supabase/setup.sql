-- ============================================================================
-- TheSwiftKit -- Complete Supabase Setup
-- ============================================================================
--
-- Run this entire file in your Supabase SQL Editor to set up all tables,
-- policies, functions, triggers, storage buckets, and indexes in one shot.
--
-- What this file creates:
--   1. profiles          -- user profile data (name, gender, contact, avatar, etc.)
--   2. user_subscriptions -- subscription mirror from RevenueCat webhooks
--   3. RLS policies      -- users can only access their own rows; service role is unrestricted
--   4. Trigger functions  -- auto-create profile on signup, auto-update timestamps
--   5. Storage bucket     -- "avatars" bucket with public read + owner-only write
--   6. Indexes            -- performance indexes on key lookup columns
--
-- Idempotent: safe to run multiple times. Uses IF NOT EXISTS and OR REPLACE
-- where supported. Policies are dropped and recreated to avoid duplicates.
-- ============================================================================


-- ============================================================================
-- 1. PROFILES TABLE
-- ============================================================================
-- Stores user profile information. The id column is a foreign key to
-- auth.users(id) so every profile is linked 1:1 with a Supabase Auth user.
--
-- Column mapping to Swift (SupabaseProfileRepository.swift):
--   id                  -> Profile.id            (String, same as auth user id)
--   name                -> Profile.name           (String)
--   gender              -> Profile.gender          (Gender enum rawValue)
--   contact             -> Profile.contact         (String)
--   avatar_url          -> Profile.avatarURL       (URL as String)
--   subscription_status -> Profile.subscriptionStatus (SubscriptionStatus rawValue)
--   updated_at          -> Profile.updatedAt       (Date)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id              uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name            text        NOT NULL DEFAULT '',
    gender          text        NOT NULL DEFAULT 'unspecified'
                                CHECK (gender IN ('unspecified', 'male', 'female', 'other')),
    contact         text        NOT NULL DEFAULT '',
    avatar_url      text,
    subscription_status text    NOT NULL DEFAULT 'Free'
                                CHECK (subscription_status IN ('Free', 'Premium Monthly', 'Premium Yearly')),
    updated_at      timestamptz DEFAULT now(),
    created_at      timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.profiles IS 'User profile data, one row per auth.users entry.';
COMMENT ON COLUMN public.profiles.id IS 'FK to auth.users(id). Same UUID as the authenticated user.';
COMMENT ON COLUMN public.profiles.gender IS 'One of: unspecified, male, female, other (matches Swift Gender enum).';
COMMENT ON COLUMN public.profiles.subscription_status IS 'One of: Free, Premium Monthly, Premium Yearly (matches Swift Profile.SubscriptionStatus enum).';


-- ============================================================================
-- 2. USER_SUBSCRIPTIONS TABLE
-- ============================================================================
-- Mirrors RevenueCat subscription state via webhook. The Edge Function
-- (user_subscriptions_webhook.ts) upserts rows here when RevenueCat fires
-- events (initial_purchase, renewal, cancellation, etc.).
--
-- Column mapping to Swift (SupabaseSubscriptionRepository.swift):
--   user_id    -> userId parameter (String, mapped to auth user id / RC app_user_id)
--   plan       -> SubscriptionPlan enum rawValue (free, pro, premium)
--   expires_at -> SubscriptionStatus.expiresAt (Date?)
--
-- Additional columns written by the Edge Function webhook:
--   email      -> subscriber email (from RC attributes or API)
--   product_id -> RevenueCat product identifier (e.g. com.swiftkit.pro.monthly)
--   last_event -> webhook event type (e.g. INITIAL_PURCHASE, RENEWAL, CANCELLATION)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
    user_id     text        PRIMARY KEY,
    email       text,
    plan        text        NOT NULL DEFAULT 'free'
                            CHECK (plan IN ('free', 'pro', 'premium')),
    expires_at  timestamptz,
    product_id  text,
    last_event  text,
    updated_at  timestamptz DEFAULT now(),
    created_at  timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.user_subscriptions IS 'Subscription data mirrored from RevenueCat via Edge Function webhook.';
COMMENT ON COLUMN public.user_subscriptions.user_id IS 'RevenueCat app_user_id. Typically matches auth.users(id) UUID as text.';
COMMENT ON COLUMN public.user_subscriptions.plan IS 'One of: free, pro, premium (matches Swift SubscriptionPlan enum).';
COMMENT ON COLUMN public.user_subscriptions.product_id IS 'RevenueCat product identifier, e.g. com.swiftkit.pro.monthly.';
COMMENT ON COLUMN public.user_subscriptions.last_event IS 'Last webhook event type received from RevenueCat.';


-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- ============================================================================
-- RLS ensures users can only access their own data.
-- The service_role key (used by Edge Functions / webhooks) bypasses RLS,
-- so webhook upserts always succeed.
-- ============================================================================

-- --- profiles RLS ---

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to make this script re-runnable
DROP POLICY IF EXISTS "Users can read their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;

-- SELECT: users can only read their own profile row
CREATE POLICY "Users can read their own profile"
    ON public.profiles
    FOR SELECT
    USING (id = auth.uid());

-- INSERT: users can only insert a row with their own auth id
CREATE POLICY "Users can insert their own profile"
    ON public.profiles
    FOR INSERT
    WITH CHECK (id = auth.uid());

-- UPDATE: users can only update their own profile row
CREATE POLICY "Users can update their own profile"
    ON public.profiles
    FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());


-- --- user_subscriptions RLS ---

ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to make this script re-runnable
DROP POLICY IF EXISTS "Users can read their own subscription"    ON public.user_subscriptions;
DROP POLICY IF EXISTS "Users can insert their own subscription"  ON public.user_subscriptions;
DROP POLICY IF EXISTS "Users can update their own subscription"  ON public.user_subscriptions;
DROP POLICY IF EXISTS "Service role can manage all subscriptions" ON public.user_subscriptions;

-- SELECT: users can read their own subscription row
-- The user_id column stores the UUID as text, so we cast auth.uid() to text.
CREATE POLICY "Users can read their own subscription"
    ON public.user_subscriptions
    FOR SELECT
    USING (user_id = auth.uid()::text);

-- INSERT: users can insert their own subscription row
CREATE POLICY "Users can insert their own subscription"
    ON public.user_subscriptions
    FOR INSERT
    WITH CHECK (user_id = auth.uid()::text);

-- UPDATE: users can update their own subscription row
CREATE POLICY "Users can update their own subscription"
    ON public.user_subscriptions
    FOR UPDATE
    USING (user_id = auth.uid()::text)
    WITH CHECK (user_id = auth.uid()::text);

-- ALL: the service_role key bypasses RLS automatically, but for explicitness
-- we add a permissive policy that the service role satisfies. Edge Functions
-- using SUPABASE_SERVICE_ROLE_KEY will match this via the role check.
CREATE POLICY "Service role can manage all subscriptions"
    ON public.user_subscriptions
    FOR ALL
    USING (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');


-- ============================================================================
-- 4. FUNCTIONS & TRIGGERS
-- ============================================================================

-- --------------------------------------------------
-- 4a. Auto-update updated_at on row modification
-- --------------------------------------------------
-- Generic trigger function that sets updated_at = now() on every UPDATE.
-- Attached to both profiles and user_subscriptions.

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_updated_at() IS 'Trigger function: auto-sets updated_at to current timestamp on UPDATE.';

-- Attach to profiles
DROP TRIGGER IF EXISTS trigger_profiles_updated_at ON public.profiles;
CREATE TRIGGER trigger_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Attach to user_subscriptions
DROP TRIGGER IF EXISTS trigger_user_subscriptions_updated_at ON public.user_subscriptions;
CREATE TRIGGER trigger_user_subscriptions_updated_at
    BEFORE UPDATE ON public.user_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- --------------------------------------------------
-- 4b. Auto-create profile on new user signup
-- --------------------------------------------------
-- When a new row is inserted into auth.users (i.e. a user signs up),
-- this trigger automatically creates a corresponding row in profiles
-- with sensible defaults. The Swift app can then upsert to fill in
-- the full profile later via ProfileSetupView.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, name, gender, contact, subscription_status)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
        'unspecified',
        COALESCE(NEW.email, ''),
        'Free'
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user() IS 'Trigger function: auto-creates a profiles row when a new auth.users row is inserted (user signup).';

-- Attach to auth.users
-- NOTE: This trigger fires on INSERT into auth.users, which happens on signup.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();


-- ============================================================================
-- 5. STORAGE -- Avatars Bucket
-- ============================================================================
-- Creates the "avatars" storage bucket used by SupabaseProfileRepository.
-- Avatars are publicly readable (so avatar_url can be used in <img> tags or
-- AsyncImage without auth headers). Only the owning user can upload/update/delete.
--
-- Supabase storage policies use the storage.objects table.
-- The bucket name is matched via bucket_id = 'avatars'.
-- Owner is derived from the folder structure: <user_id>/avatar-<uuid>.jpg
-- ============================================================================

-- Create the bucket if it doesn't exist.
-- insert ... on conflict do nothing makes this idempotent.
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies to make this script re-runnable
DROP POLICY IF EXISTS "Avatars are publicly readable"      ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatar"   ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar"   ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar"   ON storage.objects;

-- SELECT: anyone can read avatars (public bucket)
CREATE POLICY "Avatars are publicly readable"
    ON storage.objects
    FOR SELECT
    USING (bucket_id = 'avatars');

-- INSERT: authenticated users can upload to their own folder
-- The path structure is: <user_id>/avatar-<uuid>.jpg
-- We check that the first path segment matches the authenticated user's id.
CREATE POLICY "Users can upload their own avatar"
    ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'avatars'
        AND auth.role() = 'authenticated'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- UPDATE: authenticated users can update files in their own folder
CREATE POLICY "Users can update their own avatar"
    ON storage.objects
    FOR UPDATE
    USING (
        bucket_id = 'avatars'
        AND auth.role() = 'authenticated'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'avatars'
        AND auth.role() = 'authenticated'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- DELETE: authenticated users can delete files in their own folder
CREATE POLICY "Users can delete their own avatar"
    ON storage.objects
    FOR DELETE
    USING (
        bucket_id = 'avatars'
        AND auth.role() = 'authenticated'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );


-- ============================================================================
-- 6. INDEXES
-- ============================================================================
-- profiles.id is already the PRIMARY KEY, so it has an implicit unique index.
-- user_subscriptions.user_id is already the PRIMARY KEY with an implicit index.
-- Below we add additional indexes for common query patterns.
-- ============================================================================

-- Fast lookup of subscriptions by email (used by admin / support queries)
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_email
    ON public.user_subscriptions (email);

-- Fast ordering/filtering by last update time
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_updated_at
    ON public.user_subscriptions (updated_at);

-- Fast lookup of profiles by updated_at (useful for admin dashboards / exports)
CREATE INDEX IF NOT EXISTS idx_profiles_updated_at
    ON public.profiles (updated_at);

-- Fast lookup of subscriptions by plan (useful for analytics queries)
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_plan
    ON public.user_subscriptions (plan);


-- ============================================================================
-- Done! Your Supabase project is now fully configured for TheSwiftKit.
--
-- Next steps:
--   1. Deploy the Edge Function: Backend/Supabase/edge/user_subscriptions_webhook.ts
--   2. Set Edge Function env vars: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, REVENUECAT_API_KEY
--   3. Point RevenueCat webhook to your Edge Function URL
--   4. Fill in Config/Secrets.swift with your Supabase URL and anon key
--   5. Build and run the app!
-- ============================================================================
