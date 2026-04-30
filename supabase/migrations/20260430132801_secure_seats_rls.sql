/*
  # Secure seat operations with password-validated RPC

  1. Changes
    - Drop permissive UPDATE policy on `seats`
    - Add a private `seat_passwords` table (no public access) that stores the
      password for each seat. Only SECURITY DEFINER functions may read it.
    - Create `toggle_seat(p_title, p_password)` RPC. It validates the password
      server-side and toggles the seat status. This is the only path
      anon/authenticated clients can use to mutate a seat.
    - Revoke direct table write privileges from anon/authenticated.

  2. Security
    - `seats` table: SELECT allowed; INSERT/UPDATE/DELETE denied by absence
      of policies.
    - `seat_passwords` table: RLS enabled with NO policies, so it is
      completely unreadable by any client. Only server-side functions
      running as the owner can access it.
    - `toggle_seat` runs as SECURITY DEFINER so it can update `seats`
      regardless of the caller's privileges, after verifying the password.

  3. Notes
    - Password values are seeded to match the client constants so existing
      behavior is preserved.
*/

-- Drop the permissive policy
DROP POLICY IF EXISTS "Anyone can update seats" ON seats;

-- Private password table. RLS on, no policies -> no client access.
CREATE TABLE IF NOT EXISTS seat_passwords (
  title text PRIMARY KEY REFERENCES seats(title) ON DELETE CASCADE,
  password text NOT NULL
);

ALTER TABLE seat_passwords ENABLE ROW LEVEL SECURITY;

INSERT INTO seat_passwords (title, password) VALUES ('KH', '123')
  ON CONFLICT (title) DO UPDATE SET password = EXCLUDED.password;
INSERT INTO seat_passwords (title, password) VALUES ('SK', '1234')
  ON CONFLICT (title) DO UPDATE SET password = EXCLUDED.password;
INSERT INTO seat_passwords (title, password) VALUES ('SN', '12345')
  ON CONFLICT (title) DO UPDATE SET password = EXCLUDED.password;

-- Revoke any direct write privileges from public roles
REVOKE INSERT, UPDATE, DELETE ON seats FROM anon, authenticated;
REVOKE ALL ON seat_passwords FROM anon, authenticated;

-- Server-side toggle with password check
CREATE OR REPLACE FUNCTION toggle_seat(p_title text, p_password text)
RETURNS TABLE(title text, status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expected text;
  v_current text;
  v_next text;
BEGIN
  SELECT sp.password INTO v_expected
  FROM seat_passwords sp
  WHERE sp.title = p_title;

  IF v_expected IS NULL OR v_expected <> p_password THEN
    RAISE EXCEPTION 'invalid_password' USING ERRCODE = '28P01';
  END IF;

  SELECT s.status INTO v_current FROM seats s WHERE s.title = p_title;

  IF v_current IS NULL THEN
    RAISE EXCEPTION 'seat_not_found' USING ERRCODE = 'P0002';
  END IF;

  v_next := CASE WHEN v_current = 'available' THEN 'busy' ELSE 'available' END;

  UPDATE seats
    SET status = v_next, updated_at = now()
    WHERE seats.title = p_title;

  RETURN QUERY SELECT p_title, v_next;
END;
$$;

REVOKE ALL ON FUNCTION toggle_seat(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION toggle_seat(text, text) TO anon, authenticated;
