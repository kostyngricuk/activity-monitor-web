/*
  # Per-person token leaderboard view

  Aggregates `seat_sessions` rows by `person`, summing the cumulative token
  counters and surfacing the latest activity timestamp. The API route filters
  by `last_active_at` to implement window selectors (e.g. last 7 days).

  Sessions with empty `person` (legacy / pre-upgrade plugin clients) are
  excluded so they don't appear as a phantom row.
*/

CREATE OR REPLACE VIEW person_token_totals AS
SELECT
  person,
  SUM(input_tokens + output_tokens)::bigint AS total_tokens,
  SUM(input_tokens)::bigint AS input_tokens,
  SUM(output_tokens)::bigint AS output_tokens,
  SUM(cache_read_tokens)::bigint AS cache_read_tokens,
  SUM(cache_creation_tokens)::bigint AS cache_creation_tokens,
  COUNT(*)::bigint AS session_count,
  MAX(last_active_at) AS last_active_at
FROM seat_sessions
WHERE person <> ''
GROUP BY person;

GRANT SELECT ON person_token_totals TO anon, authenticated;
