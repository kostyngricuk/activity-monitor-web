'use client';

import { useEffect, useState } from 'react';
import { Seat, SeatSession } from '@/services/seats';
import { PenIcon, TrashIcon } from './icons';

const SESSION_CAP_MS = 5 * 60 * 60 * 1000;
const TICK_MS = 15_000;

function shortId(id: string): string {
  const stripped = id.startsWith('seat-') ? id.slice(5) : id;
  if (stripped.length <= 16) return stripped;
  return `${stripped.slice(0, 8)}...${stripped.slice(-8)}`;
}

function formatDuration(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

function formatTokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`;
  return `${n}`;
}

type Props = {
  seat: Seat;
  copiedId: string | null;
  onCopyId: (id: string) => void;
  onEdit: (seat: Seat) => void;
  onDelete: (seat: Seat) => void;
};

function SessionBar({ session, now }: { session: SeatSession; now: number }) {
  const startedMs = new Date(session.startedAt).getTime();
  const elapsed = Math.max(0, now - startedMs);
  const pct = Math.min(100, (elapsed / SESSION_CAP_MS) * 100);
  const totalTokens = session.inputTokens + session.outputTokens;
  const barColor =
    pct >= 90 ? 'bg-red-500' : pct >= 60 ? 'bg-amber-500' : 'bg-emerald-500';

  return (
    <div className="rounded-lg border border-slate-100 bg-slate-50 px-3 py-2">
      <div className="flex items-center justify-end text-xs">
        <span className="text-slate-500">
          {formatDuration(elapsed)} · {pct.toFixed(0)}%
          {totalTokens > 0 ? ` · ${formatTokens(totalTokens)} tok` : ''}
        </span>
      </div>
      <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-slate-200">
        <div
          className={`h-full rounded-full transition-all ${barColor}`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}

export default function SeatRow({ seat, copiedId, onCopyId, onEdit, onDelete }: Props) {
  const sessionCount = seat.session_count ?? 0;
  const isBusy = sessionCount > 0;
  const sessions = seat.activeSessions ?? [];
  const activeTokens = sessions.reduce(
    (sum, s) => sum + s.inputTokens + s.outputTokens,
    0
  );

  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (sessions.length === 0) return;
    const id = setInterval(() => setNow(Date.now()), TICK_MS);
    return () => clearInterval(id);
  }, [sessions.length]);

  return (
    <div
      className={`group rounded-xl border bg-white p-5 transition-all hover:border-slate-300 hover:shadow-md ${
        isBusy ? 'border-slate-200' : 'border-slate-200 opacity-70'
      }`}
    >
      <div className="flex items-center justify-between">
        <div className="flex flex-1 items-center gap-4 text-left">
          <div className="relative">
            <div
              className={`h-3 w-3 rounded-full transition-colors ${
                isBusy ? 'bg-emerald-500' : 'bg-slate-300'
              }`}
            />
            {isBusy && (
              <div className="absolute inset-0 h-3 w-3 rounded-full bg-emerald-500 animate-ping opacity-75" />
            )}
          </div>
          <div>
            <div className="flex flex-col items-start gap-1 sm:flex-row sm:items-center sm:gap-2">
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onCopyId(seat.id);
                }}
                title={`Click to copy seat ID (${seat.id})`}
                aria-label="Copy seat ID"
                className="rounded-md bg-slate-100 px-2 py-0.5 font-mono text-[11px] text-slate-500 transition hover:bg-slate-200 hover:text-slate-700 sm:order-last"
              >
                {copiedId === seat.id ? 'Copied!' : shortId(seat.id)}
              </button>
              <span
                className={`text-base font-semibold ${
                  isBusy ? 'text-slate-900' : 'text-slate-400'
                }`}
              >
                {seat.title}
              </span>
            </div>
            <div
              className={`text-xs font-medium ${
                isBusy ? 'text-emerald-600' : 'text-slate-400'
              }`}
            >
              {isBusy ? (
                <>
                  {sessionCount} active session{sessionCount === 1 ? '' : 's'}
                  {activeTokens > 0 && (
                    <span className="text-slate-400">
                      {' · '}
                      {formatTokens(activeTokens)} tokens
                    </span>
                  )}
                </>
              ) : (
                'Disabled'
              )}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => onEdit(seat)}
            title="Edit seat"
            aria-label="Edit seat"
            className="inline-flex h-8 w-8 items-center justify-center text-amber-500 transition hover:text-amber-600"
          >
            <PenIcon className="h-4 w-4" />
          </button>
          <button
            onClick={() => onDelete(seat)}
            title="Remove seat"
            aria-label="Remove seat"
            className="inline-flex h-8 w-8 items-center justify-center text-red-500 transition hover:text-red-600"
          >
            <TrashIcon className="h-4 w-4" />
          </button>
        </div>
      </div>

      {sessions.length > 0 && (
        <div className="mt-4 space-y-2">
          {sessions.map((s) => (
            <SessionBar key={s.id} session={s} now={now} />
          ))}
        </div>
      )}
    </div>
  );
}
