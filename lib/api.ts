import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!
);

export type RpcError = { code?: string; message: string };

export const UUID_V4_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function errorToResponse(error: RpcError) {
  if (error.code === '28P01') {
    return NextResponse.json({ error: 'Invalid password' }, { status: 401 });
  }
  if (error.code === 'P0002') {
    return NextResponse.json({ error: 'Not found' }, { status: 404 });
  }
  if (error.code === '23505') {
    return NextResponse.json({ error: 'Already exists' }, { status: 409 });
  }
  if (error.code === '22023') {
    return NextResponse.json({ error: 'Invalid input' }, { status: 400 });
  }
  return NextResponse.json({ error: error.message }, { status: 500 });
}

export async function readJsonBody(req: Request): Promise<Record<string, unknown> | null> {
  try {
    const text = await req.text();
    if (!text) return {};
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    return null;
  }
}
