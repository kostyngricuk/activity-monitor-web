import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const dynamic = 'force-dynamic';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!
);

type RpcError = { code?: string; message: string };

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

function errorToResponse(error: RpcError) {
  if (error.code === '28P01') {
    return NextResponse.json({ error: 'Invalid password' }, { status: 401 });
  }
  if (error.code === 'P0002') {
    return NextResponse.json({ error: 'Seat not found' }, { status: 404 });
  }
  if (error.code === '23505') {
    return NextResponse.json({ error: 'Seat with this title already exists' }, { status: 409 });
  }
  if (error.code === '22023') {
    return NextResponse.json({ error: 'Invalid input' }, { status: 400 });
  }
  return NextResponse.json({ error: error.message }, { status: 500 });
}

async function readBody(req: Request) {
  try {
    const text = await req.text();
    if (!text) return {};
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    return null;
  }
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

const UUID_V4_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function POST(req: Request) {
  const body = await readBody(req);
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
  const body = await readBody(req);
  if (!body) return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });

  const seatId = typeof body.seatId === 'string' ? body.seatId : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const action = typeof body.action === 'string' ? body.action : '';

  if (!seatId) return NextResponse.json({ error: 'seatId is required' }, { status: 400 });
  if (!password) return NextResponse.json({ error: 'password is required' }, { status: 400 });
  if (action !== 'start' && action !== 'end') {
    return NextResponse.json(
      { error: "action must be 'start' or 'end'" },
      { status: 400 }
    );
  }

  const { data, error } = await supabase.rpc('change_seat_session', {
    p_id: seatId,
    p_password: password,
    p_action: action,
  });

  if (error) return errorToResponse(error);
  const row = normalizeRow(data);
  return NextResponse.json(row);
}

export async function PUT(req: Request) {
  const body = await readBody(req);
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
  const body = (await readBody(req)) ?? {};

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
