'use client';

import { useCallback, useEffect, useState } from 'react';
import { supabase, SeatRow, SeatSessionRow } from '@/lib/supabase';
import { Seat, SeatSession } from './seats';

function toSeatSession(row: SeatSessionRow): SeatSession {
  return {
    id: row.id,
    seatId: row.seat_id,
    startedAt: row.started_at,
    endedAt: row.ended_at,
    lastActiveAt: row.last_active_at,
    inputTokens: Number(row.input_tokens ?? 0),
    outputTokens: Number(row.output_tokens ?? 0),
    cacheReadTokens: Number(row.cache_read_tokens ?? 0),
    cacheCreationTokens: Number(row.cache_creation_tokens ?? 0),
  };
}

function toSeat(
  row: SeatRow & { id: string },
  sessions: SeatSession[] = []
): Seat {
  return {
    id: row.id,
    title: row.title,
    status: row.status,
    session_count: row.session_count ?? 0,
    activeSessions: sessions,
  };
}

function sortSeats(seats: Seat[]): Seat[] {
  return [...seats].sort((a, b) => a.title.localeCompare(b.title));
}

function sortSessions(sessions: SeatSession[]): SeatSession[] {
  return [...sessions].sort((a, b) => a.startedAt.localeCompare(b.startedAt));
}

function upsertSession(sessions: SeatSession[], next: SeatSession): SeatSession[] {
  const idx = sessions.findIndex((s) => s.id === next.id);
  if (idx === -1) return sortSessions([...sessions, next]);
  const merged = [...sessions];
  merged[idx] = next;
  return sortSessions(merged);
}

export function useSeats() {
  const [seats, setSeats] = useState<Seat[]>([]);
  const [loading, setLoading] = useState(true);
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    let active = true;

    const load = async () => {
      const [{ data: seatRows }, { data: sessionRows }] = await Promise.all([
        supabase
          .from('seats')
          .select('id, title, status, session_count')
          .order('title'),
        supabase
          .from('seat_sessions')
          .select(
            'id, seat_id, started_at, ended_at, last_active_at, input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens'
          )
          .is('ended_at', null),
      ]);
      if (!active) return;

      const sessionsBySeat: Record<string, SeatSession[]> = {};
      ((sessionRows as SeatSessionRow[]) ?? []).forEach((row) => {
        const session = toSeatSession(row);
        const list = sessionsBySeat[session.seatId] ?? [];
        list.push(session);
        sessionsBySeat[session.seatId] = list;
      });
      Object.keys(sessionsBySeat).forEach((seatId) => {
        sessionsBySeat[seatId] = sortSessions(sessionsBySeat[seatId]);
      });

      const merged = (seatRows ?? []).map((row) =>
        toSeat(row as SeatRow & { id: string }, sessionsBySeat[row.id] ?? [])
      );
      setSeats(sortSeats(merged));
      setLoading(false);
    };

    load();

    const channel = supabase
      .channel('seats-room')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'seats' },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            const row = payload.new as SeatRow & { id: string };
            setSeats((prev) => {
              if (prev.some((s) => s.id === row.id)) return prev;
              return sortSeats([...prev, toSeat(row)]);
            });
          } else if (payload.eventType === 'UPDATE') {
            const row = payload.new as SeatRow & { id: string };
            setSeats((prev) =>
              sortSeats(
                prev.map((s) =>
                  s.id === row.id ? toSeat(row, s.activeSessions) : s
                )
              )
            );
          } else if (payload.eventType === 'DELETE') {
            const row = payload.old as { id?: string };
            if (!row?.id) return;
            setSeats((prev) => prev.filter((s) => s.id !== row.id));
          }
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'seat_sessions' },
        (payload) => {
          if (payload.eventType === 'DELETE') {
            const old = payload.old as { id?: string; seat_id?: string };
            if (!old?.id) return;
            setSeats((prev) =>
              prev.map((s) =>
                s.id === old.seat_id
                  ? { ...s, activeSessions: s.activeSessions.filter((x) => x.id !== old.id) }
                  : s
              )
            );
            return;
          }
          const row = payload.new as SeatSessionRow;
          if (!row?.id || !row?.seat_id) return;
          const session = toSeatSession(row);
          setSeats((prev) =>
            prev.map((s) => {
              if (s.id !== session.seatId) return s;
              if (session.endedAt) {
                return {
                  ...s,
                  activeSessions: s.activeSessions.filter((x) => x.id !== session.id),
                };
              }
              return { ...s, activeSessions: upsertSession(s.activeSessions, session) };
            })
          );
        }
      )
      .subscribe((status) => {
        setConnected(status === 'SUBSCRIBED');
      });

    return () => {
      active = false;
      supabase.removeChannel(channel);
    };
  }, []);

  const removeSeatLocal = useCallback((seatId: string) => {
    setSeats((prev) => prev.filter((s) => s.id !== seatId));
  }, []);

  return { seats, loading, connected, removeSeatLocal };
}
