import { NextResponse } from 'next/server';
import { supabaseAdmin as supabase } from '@/lib/api';

export const dynamic = 'force-dynamic';

const WINDOW_MS: Record<string, number> = {
  '5h': 5 * 3600 * 1000,
  '24h': 24 * 3600 * 1000,
  '7d': 7 * 24 * 3600 * 1000,
};

type Window = 'all' | '5h' | '24h' | '7d';

export async function GET(req: Request) {
  const url = new URL(req.url);
  const raw = url.searchParams.get('window') ?? 'all';
  const window: Window = (['5h', '24h', '7d', 'all'] as const).includes(raw as Window)
    ? (raw as Window)
    : 'all';

  const ms = WINDOW_MS[window];
  const since = ms ? new Date(Date.now() - ms).toISOString() : null;

  // The "5h" tab is "Current period": filter by started_at so only sessions
  // that began inside the current Claude Code 5h block are counted. Other
  // windows roll on last_active_at (any activity inside the window).
  const byStarted = window === '5h';

  const { data, error } = await supabase.rpc('seat_token_totals_since', {
    p_since: since,
    p_by_started: byStarted,
  });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
  return NextResponse.json({ window, rows: data ?? [] });
}
