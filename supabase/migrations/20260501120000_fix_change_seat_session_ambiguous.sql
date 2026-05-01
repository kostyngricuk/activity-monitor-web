/*
  # Fix ambiguous column in change_seat_session

  1. Changes
    - Re-declare `change_seat_session` so the unqualified `seat_id` references
      against the `seat_sessions` table no longer collide with the function's
      RETURNS TABLE OUT column of the same name. Without this, every PATCH
      /api/seats with a sessionId fails with
      `column reference "seat_id" is ambiguous` (SQLSTATE 42702), so seat
      status never transitions to 'busy'.

  2. Security
    - No policy changes. Function remains SECURITY DEFINER with the same
      EXECUTE privileges (anon, authenticated).
*/

DROP FUNCTION IF EXISTS change_seat_session(text, text, text, text);

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
      UPDATE seat_sessions ss
         SET ended_at = now(),
             last_active_at = now()
       WHERE ss.id = v_session_id AND ss.seat_id = p_id;
    END IF;

    SELECT count(*) INTO v_next_count
      FROM seat_sessions ss
     WHERE ss.seat_id = p_id AND ss.ended_at IS NULL;
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
