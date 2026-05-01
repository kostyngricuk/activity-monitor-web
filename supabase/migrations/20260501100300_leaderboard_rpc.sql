/*
  # Time-windowed token leaderboard

  The `person_token_totals` view aggregates across all sessions, so a
  filter on `last_active_at` (post-aggregation) is wrong — it would include a
  person's lifetime totals as long as they had any recent activity.

  This RPC pushes the time filter into the WHERE clause so SUM only spans
  sessions whose `last_active_at` falls inside the window. Pass NULL for
  all-time.
*/

CREATE OR REPLACE FUNCTION person_token_totals_since(p_since timestamptz DEFAULT NULL)
RETURNS TABLE(
  person text,
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
    s.person,
    SUM(s.input_tokens + s.output_tokens)::bigint AS total_tokens,
    SUM(s.input_tokens)::bigint AS input_tokens,
    SUM(s.output_tokens)::bigint AS output_tokens,
    SUM(s.cache_read_tokens)::bigint AS cache_read_tokens,
    SUM(s.cache_creation_tokens)::bigint AS cache_creation_tokens,
    COUNT(*)::bigint AS session_count,
    MAX(s.last_active_at) AS last_active_at
  FROM seat_sessions s
  WHERE s.person <> ''
    AND (p_since IS NULL OR s.last_active_at >= p_since)
  GROUP BY s.person
  ORDER BY total_tokens DESC;
$$;

REVOKE ALL ON FUNCTION person_token_totals_since(timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION person_token_totals_since(timestamptz) TO anon, authenticated;
