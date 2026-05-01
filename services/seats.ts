import { SeatStatus } from '@/lib/supabase';

export type SeatSession = {
  id: string;
  seatId: string;
  startedAt: string;
  endedAt: string | null;
  lastActiveAt: string;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheCreationTokens: number;
};

export type Seat = {
  id: string;
  title: string;
  status: SeatStatus;
  session_count: number;
  activeSessions: SeatSession[];
};

async function parseError(res: Response): Promise<string> {
  try {
    const body = await res.json();
    return body?.error ?? 'Something went wrong';
  } catch {
    return 'Something went wrong';
  }
}

export async function updateSeat(
  seatId: string,
  currentPassword: string,
  newTitle: string
): Promise<string | null> {
  const res = await fetch('/api/seats', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ seatId, password: currentPassword, newTitle }),
  });
  if (!res.ok) return await parseError(res);
  return null;
}

export async function deleteSeat(
  seatId: string,
  password: string
): Promise<string | null> {
  const res = await fetch('/api/seats', {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ seatId, password }),
  });
  if (!res.ok) return await parseError(res);
  return null;
}
