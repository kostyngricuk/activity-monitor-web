import { NextResponse } from 'next/server';
import {
  supabaseAdmin as supabase,
  errorToResponse,
  readJsonBody,
  UUID_V4_RE,
} from '@/lib/api';

export const dynamic = 'force-dynamic';

function asNonNegativeInt(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return 0;
  return value < 0 ? 0 : Math.floor(value);
}

export async function POST(req: Request) {
  const body = await readJsonBody(req);
  if (!body) return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });

  const seatId = typeof body.seatId === 'string' ? body.seatId : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const sessionId =
    typeof body.sessionId === 'string' ? body.sessionId.trim().toLowerCase() : '';

  if (!seatId) return NextResponse.json({ error: 'seatId is required' }, { status: 400 });
  if (!password) return NextResponse.json({ error: 'password is required' }, { status: 400 });
  if (!sessionId || !UUID_V4_RE.test(sessionId)) {
    return NextResponse.json({ error: 'sessionId must be a UUID' }, { status: 400 });
  }

  const { error } = await supabase.rpc('record_seat_session_usage', {
    p_id: seatId,
    p_password: password,
    p_session_id: sessionId,
    p_input: asNonNegativeInt(body.inputTokens),
    p_output: asNonNegativeInt(body.outputTokens),
    p_cache_read: asNonNegativeInt(body.cacheReadTokens),
    p_cache_create: asNonNegativeInt(body.cacheCreationTokens),
  });

  if (error) return errorToResponse(error);
  return NextResponse.json({ ok: true });
}
