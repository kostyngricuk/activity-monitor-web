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

export const supabase = createClient(supabaseUrl, supabaseKey);
