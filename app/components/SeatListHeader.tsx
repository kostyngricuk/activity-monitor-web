'use client';

type Props = {
  connected: boolean;
};

export default function SeatListHeader({ connected }: Props) {
  return (
    <div className="mb-8">
      <div className="flex items-center justify-between mb-2">
        <h1 className="text-3xl font-semibold tracking-tight text-slate-900">
          Account Seats
        </h1>
        <div className="flex items-center gap-2">
          <span
            className={`h-2 w-2 rounded-full ${
              connected ? 'bg-emerald-500' : 'bg-slate-300'
            }`}
          />
          <span className="text-xs font-medium text-slate-500">
            {connected ? 'Live' : 'Connecting...'}
          </span>
        </div>
      </div>
      <p className="text-sm text-slate-500">
        The monitor shows all active Claude Code sessions
      </p>
    </div>
  );
}
