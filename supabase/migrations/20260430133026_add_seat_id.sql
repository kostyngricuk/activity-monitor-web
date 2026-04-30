/*
  # Add stable seat id and id-based toggle RPC

  1. Changes
    - Add `id` text column to `seats` (unique, not null) populated with
      stable slugs.
    - Add `id` column to `seat_passwords` mapped from `seats.id`.
    - New RPC `toggle_seat_by_id(p_id, p_password)` validates the password
      server-side and toggles status. Used by the PATCH API route.

  2. Security
    - `seat_passwords` remains inaccessible to clients.
    - RPC runs as SECURITY DEFINER; password check required.
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'seats' AND column_name = 'id'
  ) THEN
    ALTER TABLE seats ADD COLUMN id text;
  END IF;
END $$;

UPDATE seats SET id = 'seat-kh' WHERE title = 'KH' AND (id IS NULL OR id = '');
UPDATE seats SET id = 'seat-sk' WHERE title = 'SK' AND (id IS NULL OR id = '');
UPDATE seats SET id = 'seat-sn' WHERE title = 'SN' AND (id IS NULL OR id = '');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'seats_id_unique'
  ) THEN
    ALTER TABLE seats ADD CONSTRAINT seats_id_unique UNIQUE (id);
  END IF;
END $$;

ALTER TABLE seats ALTER COLUMN id SET NOT NULL;

CREATE OR REPLACE FUNCTION toggle_seat_by_id(p_id text, p_password text)
RETURNS TABLE(id text, title text, status text)
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

  UPDATE seats SET status = v_next, updated_at = now() WHERE seats.title = v_title;

  RETURN QUERY SELECT p_id, v_title, v_next;
END;
$$;

REVOKE ALL ON FUNCTION toggle_seat_by_id(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION toggle_seat_by_id(text, text) TO anon, authenticated;
