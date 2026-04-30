/*
  # Seat CRUD RPCs

  1. Changes
    - `create_seat(p_title, p_password)` creates a new seat with a slug id
      derived from the title, inserts its password into `seat_passwords`.
      Returns the new row.
    - `update_seat(p_id, p_current_password, p_new_title, p_new_password)`
      verifies the current password and updates title/password. If new
      values are empty/null, they are left unchanged.
    - `delete_seat(p_id, p_password)` verifies password then deletes the
      seat (and its password row via FK cascade).

  2. Security
    - All functions SECURITY DEFINER with password checks.
    - Direct table writes remain blocked by RLS.
    - EXECUTE granted only to anon/authenticated.
*/

CREATE OR REPLACE FUNCTION create_seat(p_title text, p_password text)
RETURNS TABLE(id text, title text, status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id text;
  v_title text;
BEGIN
  v_title := btrim(coalesce(p_title, ''));

  IF v_title = '' THEN
    RAISE EXCEPTION 'invalid_title' USING ERRCODE = '22023';
  END IF;

  IF coalesce(p_password, '') = '' THEN
    RAISE EXCEPTION 'invalid_password' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (SELECT 1 FROM seats s WHERE s.title = v_title) THEN
    RAISE EXCEPTION 'seat_exists' USING ERRCODE = '23505';
  END IF;

  v_id := 'seat-' || lower(regexp_replace(v_title, '[^a-zA-Z0-9]+', '-', 'g'))
          || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 6);

  INSERT INTO seats (id, title, status) VALUES (v_id, v_title, 'available');
  INSERT INTO seat_passwords (title, password) VALUES (v_title, p_password);

  RETURN QUERY SELECT v_id, v_title, 'available'::text;
END;
$$;

CREATE OR REPLACE FUNCTION update_seat(
  p_id text,
  p_current_password text,
  p_new_title text,
  p_new_password text
)
RETURNS TABLE(id text, title text, status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title text;
  v_status text;
  v_expected text;
  v_new_title text;
  v_new_password text;
BEGIN
  SELECT s.title, s.status INTO v_title, v_status FROM seats s WHERE s.id = p_id;

  IF v_title IS NULL THEN
    RAISE EXCEPTION 'seat_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT sp.password INTO v_expected FROM seat_passwords sp WHERE sp.title = v_title;

  IF v_expected IS NULL OR v_expected <> p_current_password THEN
    RAISE EXCEPTION 'invalid_password' USING ERRCODE = '28P01';
  END IF;

  v_new_title := btrim(coalesce(p_new_title, ''));
  v_new_password := coalesce(p_new_password, '');

  IF v_new_title <> '' AND v_new_title <> v_title THEN
    IF EXISTS (SELECT 1 FROM seats s WHERE s.title = v_new_title) THEN
      RAISE EXCEPTION 'seat_exists' USING ERRCODE = '23505';
    END IF;

    UPDATE seat_passwords SET title = v_new_title WHERE title = v_title;
    UPDATE seats SET title = v_new_title, updated_at = now() WHERE id = p_id;
    v_title := v_new_title;
  END IF;

  IF v_new_password <> '' THEN
    UPDATE seat_passwords SET password = v_new_password WHERE title = v_title;
  END IF;

  RETURN QUERY SELECT p_id, v_title, v_status;
END;
$$;

CREATE OR REPLACE FUNCTION delete_seat(p_id text, p_password text)
RETURNS TABLE(id text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title text;
  v_expected text;
BEGIN
  SELECT s.title INTO v_title FROM seats s WHERE s.id = p_id;

  IF v_title IS NULL THEN
    RAISE EXCEPTION 'seat_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT sp.password INTO v_expected FROM seat_passwords sp WHERE sp.title = v_title;

  IF v_expected IS NULL OR v_expected <> p_password THEN
    RAISE EXCEPTION 'invalid_password' USING ERRCODE = '28P01';
  END IF;

  DELETE FROM seat_passwords WHERE title = v_title;
  DELETE FROM seats WHERE id = p_id;

  RETURN QUERY SELECT p_id;
END;
$$;

REVOKE ALL ON FUNCTION create_seat(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_seat(text, text) TO anon, authenticated;

REVOKE ALL ON FUNCTION update_seat(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION update_seat(text, text, text, text) TO anon, authenticated;

REVOKE ALL ON FUNCTION delete_seat(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_seat(text, text) TO anon, authenticated;
