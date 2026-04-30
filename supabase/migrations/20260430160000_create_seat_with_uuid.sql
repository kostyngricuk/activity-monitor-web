/*
  # Make create_seat accept an external UUID as the seat id

  ## Summary
    - Drop the 2-arg create_seat(p_title, p_password). The slug-based id
      generator (seat-<title>-<6hex>) is replaced by a caller-supplied UUID
      so a Claude Code plugin can own the identity per user/machine.
    - Re-create as create_seat(p_id text, p_title text, p_password text).
      p_id must be a canonical UUID v4 (lowercase hex, with dashes).
      Conflicts on either id or title raise 23505.

  ## Notes
    - seats.id stays text UNIQUE NOT NULL — UUIDs are stored as strings.
    - PATCH/PUT/DELETE RPCs (change_seat_session, update_seat, delete_seat,
      toggle_seat_by_id) already key off seats.id, so they keep working
      unchanged with the new id format.
*/

DROP FUNCTION IF EXISTS create_seat(text, text);

CREATE OR REPLACE FUNCTION create_seat(p_id text, p_title text, p_password text)
RETURNS TABLE(seat_id text, seat_title text, seat_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id text;
  v_title text;
BEGIN
  v_id := lower(btrim(coalesce(p_id, '')));
  v_title := btrim(coalesce(p_title, ''));

  IF v_id !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'invalid_id' USING ERRCODE = '22023';
  END IF;

  IF v_title = '' THEN
    RAISE EXCEPTION 'invalid_title' USING ERRCODE = '22023';
  END IF;

  IF coalesce(p_password, '') = '' THEN
    RAISE EXCEPTION 'invalid_password' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (SELECT 1 FROM seats s WHERE s.id = v_id) THEN
    RAISE EXCEPTION 'seat_exists' USING ERRCODE = '23505';
  END IF;

  IF EXISTS (SELECT 1 FROM seats s WHERE s.title = v_title) THEN
    RAISE EXCEPTION 'seat_exists' USING ERRCODE = '23505';
  END IF;

  INSERT INTO seats (id, title, status) VALUES (v_id, v_title, 'available');
  INSERT INTO seat_passwords (title, password) VALUES (v_title, p_password);

  seat_id := v_id;
  seat_title := v_title;
  seat_status := 'available';
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION create_seat(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_seat(text, text, text) TO anon, authenticated;
