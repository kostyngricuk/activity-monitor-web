import { NextResponse } from 'next/server';
import {
  supabaseAdmin as supabase,
  errorToResponse,
  readJsonBody,
  UUID_V4_RE,
} from '@/lib/api';

export const dynamic = 'force-dynamic';

type SeatRpcRow = {
  seat_id?: string;
  seat_title?: string;
  seat_status?: string;
  seat_session_count?: number;
};

function normalizeRow(data: unknown) {
  const row = (Array.isArray(data) ? data[0] : data) as SeatRpcRow | null | undefined;
  if (!row) return null;
  return {
    id: row.seat_id,
    title: row.seat_title,
    status: row.seat_status,
    sessionCount: row.seat_session_count ?? 0,
  };
}

export async function GET() {
  const { data, error } = await supabase
    .from('seats')
    .select('id, title, status, session_count')
    .order('title');

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
  return NextResponse.json(data ?? []);
}

export async function POST(req: Request) {
  const body = await readJsonBody(req);
  if (!body) return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });

  const seatId = typeof body.seatId === 'string' ? body.seatId.trim().toLowerCase() : '';
  const title = typeof body.title === 'string' ? body.title : '';
  const password = typeof body.password === 'string' ? body.password : '';

  if (!seatId) return NextResponse.json({ error: 'seatId is required' }, { status: 400 });
  if (!UUID_V4_RE.test(seatId)) {
    return NextResponse.json({ error: 'seatId must be a UUID' }, { status: 400 });
  }
  if (!title.trim()) return NextResponse.json({ error: 'title is required' }, { status: 400 });
  if (!password) return NextResponse.json({ error: 'password is required' }, { status: 400 });

  const { data, error } = await supabase.rpc('create_seat', {
    p_id: seatId,
    p_title: title,
    p_password: password,
  });

  if (error) return errorToResponse(error);
  const row = normalizeRow(data);
  return NextResponse.json(row, { status: 201 });
}

export async function PATCH(req: Request) {
  const body = await readJsonBody(req);
  if (!body) return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });

  const seatId = typeof body.seatId === 'string' ? body.seatId : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const action = typeof body.action === 'string' ? body.action : '';
  const sessionId =
    typeof body.sessionId === 'string' ? body.sessionId.trim().toLowerCase() : '';

  if (!seatId) return NextResponse.json({ error: 'seatId is required' }, { status: 400 });
  if (!password) return NextResponse.json({ error: 'password is required' }, { status: 400 });
  if (action !== 'start' && action !== 'end') {
    return NextResponse.json(
      { error: "action must be 'start' or 'end'" },
      { status: 400 }
    );
  }
  if (sessionId && !UUID_V4_RE.test(sessionId)) {
    return NextResponse.json({ error: 'sessionId must be a UUID' }, { status: 400 });
  }

  const { data, error } = await supabase.rpc('change_seat_session', {
    p_id: seatId,
    p_password: password,
    p_action: action,
    p_session_id: sessionId || null,
  });

  if (error) return errorToResponse(error);
  const row = normalizeRow(data);
  return NextResponse.json(row);
}

export async function PUT(req: Request) {
  const body = await readJsonBody(req);
  if (!body) return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });

  const seatId = typeof body.seatId === 'string' ? body.seatId : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const newTitle = typeof body.newTitle === 'string' ? body.newTitle : '';
  const newPassword = typeof body.newPassword === 'string' ? body.newPassword : '';

  if (!seatId) return NextResponse.json({ error: 'seatId is required' }, { status: 400 });
  if (!password) return NextResponse.json({ error: 'password is required' }, { status: 400 });
  if (!newTitle.trim() && !newPassword) {
    return NextResponse.json({ error: 'Provide newTitle or newPassword' }, { status: 400 });
  }

  const { data, error } = await supabase.rpc('update_seat', {
    p_id: seatId,
    p_current_password: password,
    p_new_title: newTitle,
    p_new_password: newPassword,
  });

  if (error) return errorToResponse(error);
  const row = normalizeRow(data);
  return NextResponse.json(row);
}

export async function DELETE(req: Request) {
  const url = new URL(req.url);
  const body = (await readJsonBody(req)) ?? {};

  const seatId =
    (typeof body.seatId === 'string' && body.seatId) ||
    url.searchParams.get('seatId') ||
    '';
  const password =
    (typeof body.password === 'string' && body.password) ||
    url.searchParams.get('password') ||
    '';

  if (!seatId) return NextResponse.json({ error: 'seatId is required' }, { status: 400 });
  if (!password) return NextResponse.json({ error: 'password is required' }, { status: 400 });

  const { data, error } = await supabase.rpc('delete_seat', {
    p_id: seatId,
    p_password: password,
  });

  if (error) return errorToResponse(error);
  const row = normalizeRow(data);
  return NextResponse.json(row);
}
