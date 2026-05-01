/*
  # Track per-Claude-Code-session activity and token usage

  1. New Tables
    - `seat_sessions`
      - `id` (text, PK) — the Claude Code `session_id` (UUID v4) provided to
        plugin hooks via stdin.
      - `seat_id` (text, FK -> seats.id) — owning seat.
      - `person` (text) — human identifier captured at plugin setup. Empty
        string when an old plugin client (no `person` field) writes a row.
      - `started_at` (timestamptz) — when the SessionStart hook fired.
      - `ended_at` (timestamptz, nullable) — null = session is active.
      - `last_active_at` (timestamptz) — bumped on each Stop event.
      - `input_tokens`, `output_tokens`, `cache_read_tokens`,
        `cache_creation_tokens` (bigint) — cumulative totals replayed from
        the transcript on every Stop / SessionEnd.

  2. Security
    - RLS enabled. Public SELECT is allowed (mirrors the `seats` dashboard
      model). All writes happen through SECURITY DEFINER RPCs, which is
      enforced by REVOKEing INSERT/UPDATE/DELETE from anon + authenticated.

  3. Realtime
    - Added to `supabase_realtime` so the dashboard's per-seat session bars
      update live.
*/

CREATE TABLE IF NOT EXISTS seat_sessions (
  id text PRIMARY KEY,
  seat_id text NOT NULL REFERENCES seats(id) ON DELETE CASCADE,
  person text NOT NULL DEFAULT '',
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  last_active_at timestamptz NOT NULL DEFAULT now(),
  input_tokens bigint NOT NULL DEFAULT 0,
  output_tokens bigint NOT NULL DEFAULT 0,
  cache_read_tokens bigint NOT NULL DEFAULT 0,
  cache_creation_tokens bigint NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS seat_sessions_seat_id_active_idx
  ON seat_sessions (seat_id) WHERE ended_at IS NULL;

CREATE INDEX IF NOT EXISTS seat_sessions_person_idx
  ON seat_sessions (person) WHERE person <> '';

CREATE INDEX IF NOT EXISTS seat_sessions_last_active_idx
  ON seat_sessions (last_active_at);

ALTER TABLE seat_sessions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'seat_sessions' AND policyname = 'Anyone can view seat_sessions'
  ) THEN
    CREATE POLICY "Anyone can view seat_sessions"
      ON seat_sessions FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;
END $$;

REVOKE INSERT, UPDATE, DELETE ON seat_sessions FROM anon, authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'seat_sessions'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE seat_sessions';
  END IF;
END $$;
