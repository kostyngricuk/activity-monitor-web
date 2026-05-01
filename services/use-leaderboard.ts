'use client';

import { useEffect, useState } from 'react';

export type LeaderboardWindow = 'all' | '7d' | '24h' | '5h';

export type LeaderboardRow = {
  seat_id: string;
  title: string;
  total_tokens: number;
  input_tokens: number;
  output_tokens: number;
  cache_read_tokens: number;
  cache_creation_tokens: number;
  session_count: number;
  last_active_at: string;
};

const REFRESH_MS = 30_000;

export function useLeaderboard(window: LeaderboardWindow) {
  const [rows, setRows] = useState<LeaderboardRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    const controller = new AbortController();

    const load = async () => {
      try {
        const res = await fetch(`/api/leaderboard?window=${window}`, {
          signal: controller.signal,
          cache: 'no-store',
        });
        if (!active) return;
        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          setError(body?.error ?? `HTTP ${res.status}`);
          return;
        }
        const body = (await res.json()) as { rows?: LeaderboardRow[] };
        if (!active) return;
        setRows(
          (body.rows ?? []).map((r) => ({
            ...r,
            total_tokens: Number(r.total_tokens ?? 0),
            input_tokens: Number(r.input_tokens ?? 0),
            output_tokens: Number(r.output_tokens ?? 0),
            cache_read_tokens: Number(r.cache_read_tokens ?? 0),
            cache_creation_tokens: Number(r.cache_creation_tokens ?? 0),
            session_count: Number(r.session_count ?? 0),
          }))
        );
        setError(null);
      } catch (e) {
        if (!active) return;
        if ((e as { name?: string }).name === 'AbortError') return;
        setError((e as Error).message);
      } finally {
        if (active) setLoading(false);
      }
    };

    load();
    const id = setInterval(load, REFRESH_MS);

    return () => {
      active = false;
      controller.abort();
      clearInterval(id);
    };
  }, [window]);

  return { rows, loading, error };
}
