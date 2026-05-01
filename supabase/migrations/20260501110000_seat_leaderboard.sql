/*
  # Seat-based leaderboard (replaces person-based aggregation)

  Drops the `person` column on `seat_sessions` plus its index, and replaces
  the person-based view + RPC with seat-based equivalents that aggregate by
  `seat_id` (joined to `seats` for the human-readable title).

  The leaderboard RPC gains a `p_by_started` flag:
    - false (default) → filter by `last_active_at` (rolling window: 24h, 7d, all).
    - true            → filter by `started_at` (current 5h period: only sessions
                        whose start is within the window).

  Filtering by `started_at` for the "current period" tab matches Claude Code's
  block model: each new block resets `started_at` for its first session, so the
  earliest started_at in the last 5h is effectively the period anchor.
*/

DROP FUNCTION IF EXISTS person_token_totals_since(timestamptz);
DROP VIEW IF EXISTS person_token_totals;

DROP INDEX IF EXISTS seat_sessions_person_idx;
ALTER TABLE seat_sessions DROP COLUMN IF EXISTS person;

DROP FUNCTION IF EXISTS change_seat_session(text, text, text, text, text);

CREATE OR REPLACE FUNCTION change_seat_session(
  p_id text,
  p_password text,
  p_action text,
  p_session_id text DEFAULT NULL
)
RETURNS TABLE(
  seat_id text,
  seat_title text,
  seat_status text,
  seat_session_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title text;
  v_expected text;
  v_count integer;
  v_next_count integer;
  v_next_status text;
  v_session_id text;
BEGIN
  IF p_action IS NULL OR p_action NOT IN ('start', 'end') THEN
    RAISE EXCEPTION 'invalid_action' USING ERRCODE = '22023';
  END IF;

  SELECT s.title INTO v_title FROM seats s WHERE s.id = p_id;

  IF v_title IS NULL THEN
    RAISE EXCEPTION 'seat_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT sp.password INTO v_expected FROM seat_passwords sp WHERE sp.title = v_title;

  IF v_expected IS NULL OR v_expected <> p_password THEN
    RAISE EXCEPTION 'invalid_password' USING ERRCODE = '28P01';
  END IF;

  v_session_id := NULLIF(btrim(coalesce(p_session_id, '')), '');

  IF v_session_id IS NOT NULL THEN
    IF p_action = 'start' THEN
      INSERT INTO seat_sessions (id, seat_id, started_at, last_active_at)
      VALUES (v_session_id, p_id, now(), now())
      ON CONFLICT (id) DO UPDATE
        SET seat_id = EXCLUDED.seat_id,
            ended_at = NULL,
            last_active_at = now();
    ELSE
      UPDATE seat_sessions
         SET ended_at = now(),
             last_active_at = now()
       WHERE id = v_session_id AND seat_id = p_id;
    END IF;

    SELECT count(*) INTO v_next_count
      FROM seat_sessions
     WHERE seat_id = p_id AND ended_at IS NULL;
  ELSE
    SELECT s.session_count INTO v_count FROM seats s WHERE s.id = p_id;
    IF p_action = 'start' THEN
      v_next_count := v_count + 1;
    ELSE
      v_next_count := GREATEST(v_count - 1, 0);
    END IF;
  END IF;

  v_next_status := CASE WHEN v_next_count > 0 THEN 'busy' ELSE 'available' END;

  UPDATE seats s
     SET session_count = v_next_count,
         status = v_next_status,
         updated_at = now()
   WHERE s.id = p_id;

  seat_id := p_id;
  seat_title := v_title;
  seat_status := v_next_status;
  seat_session_count := v_next_count;
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION change_seat_session(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION change_seat_session(text, text, text, text) TO anon, authenticated;

CREATE OR REPLACE VIEW seat_token_totals AS
SELECT
  s.id   AS seat_id,
  s.title,
  SUM(ss.input_tokens + ss.output_tokens)::bigint AS total_tokens,
  SUM(ss.input_tokens)::bigint AS input_tokens,
  SUM(ss.output_tokens)::bigint AS output_tokens,
  SUM(ss.cache_read_tokens)::bigint AS cache_read_tokens,
  SUM(ss.cache_creation_tokens)::bigint AS cache_creation_tokens,
  COUNT(*)::bigint AS session_count,
  MAX(ss.last_active_at) AS last_active_at
FROM seat_sessions ss
JOIN seats s ON s.id = ss.seat_id
GROUP BY s.id, s.title;

GRANT SELECT ON seat_token_totals TO anon, authenticated;

CREATE OR REPLACE FUNCTION seat_token_totals_since(
  p_since timestamptz DEFAULT NULL,
  p_by_started boolean DEFAULT false
)
RETURNS TABLE(
  seat_id text,
  title text,
  total_tokens bigint,
  input_tokens bigint,
  output_tokens bigint,
  cache_read_tokens bigint,
  cache_creation_tokens bigint,
  session_count bigint,
  last_active_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.id   AS seat_id,
    s.title,
    SUM(ss.input_tokens + ss.output_tokens)::bigint AS total_tokens,
    SUM(ss.input_tokens)::bigint AS input_tokens,
    SUM(ss.output_tokens)::bigint AS output_tokens,
    SUM(ss.cache_read_tokens)::bigint AS cache_read_tokens,
    SUM(ss.cache_creation_tokens)::bigint AS cache_creation_tokens,
    COUNT(*)::bigint AS session_count,
    MAX(ss.last_active_at) AS last_active_at
  FROM seat_sessions ss
  JOIN seats s ON s.id = ss.seat_id
  WHERE p_since IS NULL
     OR (p_by_started AND ss.started_at >= p_since)
     OR (NOT p_by_started AND ss.last_active_at >= p_since)
  GROUP BY s.id, s.title
  ORDER BY total_tokens DESC;
$$;

REVOKE ALL ON FUNCTION seat_token_totals_since(timestamptz, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION seat_token_totals_since(timestamptz, boolean) TO anon, authenticated;
