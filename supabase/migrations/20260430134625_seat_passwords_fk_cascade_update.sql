/*
  # Fix seat title updates cascading to seat_passwords

  1. Changes
    - Replace the existing FK `seat_passwords_title_fkey` with one that
      also cascades on UPDATE, so renaming a seat's title propagates
      automatically to `seat_passwords.title` and never leaves a window
      where the child row points at a non-existent parent.
    - Simplify `update_seat` so it no longer updates `seat_passwords.title`
      manually — the cascade handles it.

  2. Security
    - No policy changes. Functions remain SECURITY DEFINER.
*/

ALTER TABLE seat_passwords
  DROP CONSTRAINT IF EXISTS seat_passwords_title_fkey;

ALTER TABLE seat_passwords
  ADD CONSTRAINT seat_passwords_title_fkey
  FOREIGN KEY (title) REFERENCES seats(title) ON UPDATE CASCADE ON DELETE CASCADE;

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
