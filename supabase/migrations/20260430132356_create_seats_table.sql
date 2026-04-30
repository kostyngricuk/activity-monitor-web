/*
  # Create seats table for real-time seat management

  1. New Tables
    - `seats`
      - `title` (text, primary key) - The seat identifier (e.g., "KH", "SK", "SN")
      - `status` (text) - Either 'available' or 'busy'
      - `updated_at` (timestamptz) - Last status change timestamp

  2. Security
    - Enable RLS on `seats` table
    - Allow public read access so anyone can see seat statuses
    - Allow public update access so anyone with the password (validated client-side) can toggle status

  3. Seed Data
    - Insert the three seats: KH, SK, SN (all available by default)

  4. Realtime
    - Enable realtime replication on the seats table
*/

CREATE TABLE IF NOT EXISTS seats (
  title text PRIMARY KEY,
  status text NOT NULL DEFAULT 'available',
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE seats ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'seats' AND policyname = 'Anyone can view seats') THEN
    CREATE POLICY "Anyone can view seats"
      ON seats FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'seats' AND policyname = 'Anyone can update seats') THEN
    CREATE POLICY "Anyone can update seats"
      ON seats FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

INSERT INTO seats (title, status) VALUES ('KH', 'available') ON CONFLICT (title) DO NOTHING;
INSERT INTO seats (title, status) VALUES ('SK', 'available') ON CONFLICT (title) DO NOTHING;
INSERT INTO seats (title, status) VALUES ('SN', 'available') ON CONFLICT (title) DO NOTHING;

ALTER PUBLICATION supabase_realtime ADD TABLE seats;
