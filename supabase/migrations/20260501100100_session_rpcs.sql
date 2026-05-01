/*
  # Session-aware RPCs

  1. Replaces `change_seat_session(text,text,text)` with a 5-arg version that
     accepts an optional `p_session_id` (Claude Code session UUID) and
     optional `p_person` (human identifier from plugin config).

     - On `start`: if a session_id is provided, INSERT into `seat_sessions`
       (idempotent on conflict). Then recompute `seats.session_count` from
       the count of rows in `seat_sessions` where `ended_at IS NULL`. If no
       session_id is provided, fall back to the simple counter increment so
       older plugin clients keep working.
     - On `end`: if a session_id is provided, mark that row's `ended_at`.
       Recompute count + status. Without a session_id, decrement counter.

  2. Adds `record_seat_session_usage(p_id, p_password, p_session_id,
     p_input, p_output, p_cache_read, p_cache_create)`. Validates the
     password the same way as `change_seat_session`, then writes the
     cumulative token totals onto the row and bumps `last_active_at`.
*/

DROP FUNCTION IF EXISTS change_seat_session(text, text, text);

CREATE OR REPLACE FUNCTION change_seat_session(
  p_id text,
  p_password text,
  p_action text,
  p_session_id text DEFAULT NULL,
  p_person text DEFAULT NULL
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
  v_person text;
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
  v_person := btrim(coalesce(p_person, ''));

  IF v_session_id IS NOT NULL THEN
    IF p_action = 'start' THEN
      INSERT INTO seat_sessions (id, seat_id, person, started_at, last_active_at)
      VALUES (v_session_id, p_id, v_person, now(), now())
      ON CONFLICT (id) DO UPDATE
        SET seat_id = EXCLUDED.seat_id,
            person = CASE
              WHEN EXCLUDED.person <> '' THEN EXCLUDED.person
              ELSE seat_sessions.person
            END,
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

REVOKE ALL ON FUNCTION change_seat_session(text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION change_seat_session(text, text, text, text, text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION record_seat_session_usage(
  p_id text,
  p_password text,
  p_session_id text,
  p_input bigint,
  p_output bigint,
  p_cache_read bigint,
  p_cache_create bigint
)
RETURNS TABLE(
  out_session_id text,
  out_input_tokens bigint,
  out_output_tokens bigint,
  out_cache_read_tokens bigint,
  out_cache_creation_tokens bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title text;
  v_expected text;
  v_session_id text;
  v_input bigint;
  v_output bigint;
  v_cache_read bigint;
  v_cache_create bigint;
BEGIN
  v_session_id := NULLIF(btrim(coalesce(p_session_id, '')), '');
  IF v_session_id IS NULL THEN
    RAISE EXCEPTION 'invalid_session_id' USING ERRCODE = '22023';
  END IF;

  SELECT s.title INTO v_title FROM seats s WHERE s.id = p_id;
  IF v_title IS NULL THEN
    RAISE EXCEPTION 'seat_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT sp.password INTO v_expected FROM seat_passwords sp WHERE sp.title = v_title;
  IF v_expected IS NULL OR v_expected <> p_password THEN
    RAISE EXCEPTION 'invalid_password' USING ERRCODE = '28P01';
  END IF;

  v_input := GREATEST(coalesce(p_input, 0), 0);
  v_output := GREATEST(coalesce(p_output, 0), 0);
  v_cache_read := GREATEST(coalesce(p_cache_read, 0), 0);
  v_cache_create := GREATEST(coalesce(p_cache_create, 0), 0);

  UPDATE seat_sessions
     SET input_tokens = GREATEST(input_tokens, v_input),
         output_tokens = GREATEST(output_tokens, v_output),
         cache_read_tokens = GREATEST(cache_read_tokens, v_cache_read),
         cache_creation_tokens = GREATEST(cache_creation_tokens, v_cache_create),
         last_active_at = now()
   WHERE id = v_session_id AND seat_id = p_id
   RETURNING input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens
   INTO v_input, v_output, v_cache_read, v_cache_create;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session_not_found' USING ERRCODE = 'P0002';
  END IF;

  out_session_id := v_session_id;
  out_input_tokens := v_input;
  out_output_tokens := v_output;
  out_cache_read_tokens := v_cache_read;
  out_cache_creation_tokens := v_cache_create;
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION record_seat_session_usage(text, text, text, bigint, bigint, bigint, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION record_seat_session_usage(text, text, text, bigint, bigint, bigint, bigint) TO anon, authenticated;
