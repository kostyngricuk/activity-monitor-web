import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!;

export type SeatStatus = 'available' | 'busy';

export type SeatRow = {
  title: string;
  status: SeatStatus;
  session_count: number;
  updated_at: string;
};

export type SeatSessionRow = {
  id: string;
  seat_id: string;
  started_at: string;
  ended_at: string | null;
  last_active_at: string;
  input_tokens: number;
  output_tokens: number;
  cache_read_tokens: number;
  cache_creation_tokens: number;
};

export const supabase = createClient(supabaseUrl, supabaseKey);
