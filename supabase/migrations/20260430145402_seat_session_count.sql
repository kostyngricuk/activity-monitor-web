/*
  # Track active session count on seats

  1. Schema
    - Add `session_count integer NOT NULL DEFAULT 0` to `seats`. Counts how many
      Claude Code sessions are currently using the seat. Status is derived:
      `busy` when count > 0, `available` when count = 0.

  2. Functions
    - Drop `toggle_seat_by_id` (binary toggle no longer fits the multi-session model).
    - Add `change_seat_session(p_id, p_password, p_action)` where p_action is
      `start` (increment) or `end` (decrement, clamped at 0). Updates status to
      match the new count and returns the new row including session count.

  3. Security
    - Same SECURITY DEFINER pattern. EXECUTE granted to anon, authenticated.
*/

ALTER TABLE seats
  ADD COLUMN IF NOT EXISTS session_count integer NOT NULL DEFAULT 0;

UPDATE seats SET session_count = 1 WHERE status = 'busy' AND session_count = 0;

DROP FUNCTION IF EXISTS toggle_seat_by_id(text, text);

CREATE OR REPLACE FUNCTION change_seat_session(
  p_id text,
  p_password text,
  p_action text
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

  SELECT s.session_count INTO v_count FROM seats s WHERE s.id = p_id;

  IF p_action = 'start' THEN
    v_next_count := v_count + 1;
  ELSE
    v_next_count := GREATEST(v_count - 1, 0);
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

REVOKE ALL ON FUNCTION change_seat_session(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION change_seat_session(text, text, text) TO anon, authenticated;
