'use client';

import { Seat } from '@/services/seats';
import { PenIcon, TrashIcon } from './icons';

function shortId(id: string): string {
  const stripped = id.startsWith('seat-') ? id.slice(5) : id;
  if (stripped.length <= 16) return stripped;
  return `${stripped.slice(0, 8)}...${stripped.slice(-8)}`;
}

type Props = {
  seat: Seat;
  copiedId: string | null;
  onCopyId: (id: string) => void;
  onEdit: (seat: Seat) => void;
  onDelete: (seat: Seat) => void;
};

export default function SeatRow({ seat, copiedId, onCopyId, onEdit, onDelete }: Props) {
  const sessionCount = seat.session_count ?? 0;
  const isBusy = sessionCount > 0;

  return (
    <div
      className={`group flex items-center justify-between rounded-xl border bg-white p-5 transition-all hover:border-slate-300 hover:shadow-md ${
        isBusy ? 'border-slate-200' : 'border-slate-200 opacity-70'
      }`}
    >
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
            {isBusy
              ? `${sessionCount} active session${sessionCount === 1 ? '' : 's'}`
              : 'Disabled'}
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
  );
}
