-- Migration: 029_rename_users_supabase_id_to_access_subject.sql
-- Issue #1058: users.supabase_id holds the first Cloudflare Access subject
-- (`sub`) seen for a user; it is not a Supabase id. Rename it to
-- users.access_subject, together with the index and constraint names that
-- migration 026 created for it.
--
-- RENAME COLUMN keeps the data, the indexes, the foreign key and any row-level
-- policies attached to the column. Function bodies are stored as text and are
-- NOT rewritten, so the Supabase-only handle_new_user() trigger function from
-- migration 026 is recreated below with the new column name.
--
-- Idempotent: every step checks the current state first, so running it on a
-- database that is already renamed (or was renamed by hand) changes nothing.

DO $migration$
DECLARE
  has_old BOOLEAN;
  has_new BOOLEAN;
BEGIN
  IF to_regclass('public.users') IS NULL THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'supabase_id'
  ) INTO has_old;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'access_subject'
  ) INTO has_new;

  IF has_old AND has_new THEN
    -- Never guess which column holds the real subjects: stop and let an
    -- operator decide. The migration transaction rolls back unchanged.
    RAISE EXCEPTION
      'public.users has both supabase_id and access_subject; resolve by hand before migration 029';
  ELSIF has_old THEN
    ALTER TABLE public.users RENAME COLUMN supabase_id TO access_subject;
  ELSIF NOT has_new THEN
    -- Neither column exists (026 has not run on this table): nothing to rename.
    RETURN;
  END IF;

  IF to_regclass('public.idx_users_supabase_id_unique') IS NOT NULL
     AND to_regclass('public.idx_users_access_subject_unique') IS NULL THEN
    ALTER INDEX public.idx_users_supabase_id_unique
      RENAME TO idx_users_access_subject_unique;
  END IF;

  IF to_regclass('public.idx_users_supabase_id') IS NOT NULL
     AND to_regclass('public.idx_users_access_subject') IS NULL THEN
    ALTER INDEX public.idx_users_supabase_id
      RENAME TO idx_users_access_subject;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'users_supabase_id_fkey'
      AND conrelid = 'public.users'::regclass
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'users_access_subject_fkey'
      AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users
      RENAME CONSTRAINT users_supabase_id_fkey TO users_access_subject_fkey;
  END IF;

  COMMENT ON COLUMN public.users.access_subject IS
    'First Cloudflare Access subject (sub) seen for this user; further subjects are in user_auth_subjects. Named supabase_id before migration 029.';

  -- Supabase only: migration 026 installed a trigger function whose body
  -- names the old column. Recreate it so new auth.users rows keep syncing.
  IF to_regclass('auth.users') IS NOT NULL
     AND to_regprocedure('public.handle_new_user()') IS NOT NULL THEN
    EXECUTE $fn$
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (access_subject, email, name, nickname, picture, email_verified, locale)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'nickname',
    new.raw_user_meta_data->>'picture',
    new.email_confirmed_at IS NOT NULL,
    new.raw_user_meta_data->>'locale'
  )
  ON CONFLICT (access_subject) DO UPDATE SET
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
  END IF;
END
$migration$;
