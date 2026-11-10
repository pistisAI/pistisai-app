-- Migration: 026_create_public_users_table.sql
-- Give public.users the supabase_id column the api-backend looks users up by
-- (it holds the first Cloudflare Access subject). Works on plain PostgreSQL,
-- where schema.pg.sql already created users, and on Supabase, where the
-- auth schema also gets the sync trigger and row-level policies.

CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255),
  name VARCHAR(255),
  nickname VARCHAR(255),
  picture TEXT,
  email_verified BOOLEAN DEFAULT FALSE,
  locale VARCHAR(10),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS supabase_id UUID;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_supabase_id_unique
  ON public.users(supabase_id);

-- Index for fast lookup by supabase_id
CREATE INDEX IF NOT EXISTS idx_users_supabase_id ON public.users(supabase_id);

-- Index for email lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

-- Supabase only: link auth.users, policies, and the sync trigger.
DO $migration$
BEGIN
  IF to_regclass('auth.users') IS NULL THEN
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_supabase_id_fkey'
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_supabase_id_fkey
      FOREIGN KEY (supabase_id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;

  ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'users' AND policyname = 'Users can read own data'
  ) THEN
    EXECUTE 'CREATE POLICY "Users can read own data" ON public.users
      FOR SELECT USING (auth.uid() = supabase_id)';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'users' AND policyname = 'Users can update own data'
  ) THEN
    EXECUTE 'CREATE POLICY "Users can update own data" ON public.users
      FOR UPDATE USING (auth.uid() = supabase_id)';
  END IF;

  EXECUTE $fn$
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (supabase_id, email, name, nickname, picture, email_verified, locale)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'nickname',
    new.raw_user_meta_data->>'picture',
    new.email_confirmed_at IS NOT NULL,
    new.raw_user_meta_data->>'locale'
  )
  ON CONFLICT (supabase_id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    nickname = EXCLUDED.nickname,
    picture = EXCLUDED.picture,
    email_verified = EXCLUDED.email_verified,
    locale = EXCLUDED.locale,
    updated_at = NOW();
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
$fn$;

  EXECUTE 'DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users';
  EXECUTE 'CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user()';
END
$migration$;

-- Create user_sessions table if not exists (referenced by auth-service.js)
CREATE TABLE IF NOT EXISTS public.user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  jwt_token_hash VARCHAR(64) UNIQUE NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  expires_at TIMESTAMPTZ NOT NULL,
  last_activity TIMESTAMPTZ DEFAULT NOW(),
  ip_address INET,
  user_agent TEXT,
  session_token VARCHAR(64),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON public.user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token_hash ON public.user_sessions(jwt_token_hash);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON public.user_sessions(expires_at);

-- Create security_events table if not exists
CREATE TABLE IF NOT EXISTS public.security_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type VARCHAR(100) NOT NULL,
  details JSONB,
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_security_events_type ON public.security_events(event_type);
CREATE INDEX IF NOT EXISTS idx_security_events_created_at ON public.security_events(created_at);
