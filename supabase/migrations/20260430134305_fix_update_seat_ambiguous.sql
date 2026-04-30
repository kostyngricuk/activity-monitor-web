/*
  # Fix ambiguous column in update_seat

  1. Changes
    - Rename the OUT parameters of `update_seat`, `create_seat`, `toggle_seat_by_id`,
      and `delete_seat` so they no longer shadow the actual column names. The
      previous RETURNS TABLE(id, title, status) declarations created implicit
      variables that clashed with table columns inside the function bodies
      (e.g. "column reference title is ambiguous").

  2. Security
    - No policy changes. Functions remain SECURITY DEFINER with the same
      EXECUTE privileges.
*/

DROP FUNCTION IF EXISTS create_seat(text, text);
DROP FUNCTION IF EXISTS update_seat(text, text, text, text);
DROP FUNCTION IF EXISTS delete_seat(text, text);
DROP FUNCTION IF EXISTS toggle_seat_by_id(text, text);

CREATE OR REPLACE FUNCTION create_seat(p_title text, p_password text)
RETURNS TABLE(seat_id text, seat_title text, seat_status text)
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

  seat_id := v_id;
  seat_title := v_title;
  seat_status := 'available';
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION update_seat(
  p_id text,
  p_current_password text,
  p_new_title text,
  p_new_password text
)
RETURNS TABLE(seat_id text, seat_title text, seat_status text)
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

    UPDATE seat_passwords sp SET title = v_new_title WHERE sp.title = v_title;
    UPDATE seats s SET title = v_new_title, updated_at = now() WHERE s.id = p_id;
    v_title := v_new_title;
  END IF;

  IF v_new_password <> '' THEN
    UPDATE seat_passwords sp SET password = v_new_password WHERE sp.title = v_title;
  END IF;

  seat_id := p_id;
  seat_title := v_title;
  seat_status := v_status;
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION delete_seat(p_id text, p_password text)
RETURNS TABLE(seat_id text)
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

  DELETE FROM seat_passwords sp WHERE sp.title = v_title;
  DELETE FROM seats s WHERE s.id = p_id;

  seat_id := p_id;
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION toggle_seat_by_id(p_id text, p_password text)
RETURNS TABLE(seat_id text, seat_title text, seat_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title text;
  v_expected text;
  v_current text;
  v_next text;
BEGIN
  SELECT s.title INTO v_title FROM seats s WHERE s.id = p_id;

  IF v_title IS NULL THEN
    RAISE EXCEPTION 'seat_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT sp.password INTO v_expected FROM seat_passwords sp WHERE sp.title = v_title;

  IF v_expected IS NULL OR v_expected <> p_password THEN
    RAISE EXCEPTION 'invalid_password' USING ERRCODE = '28P01';
  END IF;

  SELECT s.status INTO v_current FROM seats s WHERE s.title = v_title;

  v_next := CASE WHEN v_current = 'available' THEN 'busy' ELSE 'available' END;

  UPDATE seats s SET status = v_next, updated_at = now() WHERE s.title = v_title;

  seat_id := p_id;
  seat_title := v_title;
  seat_status := v_next;
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION create_seat(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_seat(text, text) TO anon, authenticated;

REVOKE ALL ON FUNCTION update_seat(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION update_seat(text, text, text, text) TO anon, authenticated;

REVOKE ALL ON FUNCTION delete_seat(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_seat(text, text) TO anon, authenticated;

REVOKE ALL ON FUNCTION toggle_seat_by_id(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION toggle_seat_by_id(text, text) TO anon, authenticated;
