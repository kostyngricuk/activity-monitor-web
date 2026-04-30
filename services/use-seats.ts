'use client';

import { useCallback, useEffect, useState } from 'react';
import { supabase, SeatRow } from '@/lib/supabase';
import { Seat } from './seats';

function toSeat(row: SeatRow & { id: string }): Seat {
  return {
    id: row.id,
    title: row.title,
    status: row.status,
    session_count: row.session_count ?? 0,
  };
}

export function useSeats() {
  const [seats, setSeats] = useState<Seat[]>([]);
  const [loading, setLoading] = useState(true);
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    let active = true;

    const load = async () => {
      const { data } = await supabase
        .from('seats')
        .select('id, title, status, session_count')
        .order('title');
      if (!active) return;
      setSeats((data as Seat[]) ?? []);
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
              return [...prev, toSeat(row)].sort((a, b) =>
                a.title.localeCompare(b.title)
              );
            });
          } else if (payload.eventType === 'UPDATE') {
            const row = payload.new as SeatRow & { id: string };
            setSeats((prev) =>
              prev
                .map((s) => (s.id === row.id ? toSeat(row) : s))
                .sort((a, b) => a.title.localeCompare(b.title))
            );
          } else if (payload.eventType === 'DELETE') {
            const row = payload.old as { id?: string };
            if (!row?.id) return;
            setSeats((prev) => prev.filter((s) => s.id !== row.id));
          }
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
