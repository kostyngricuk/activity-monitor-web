'use client';

import { useState } from 'react';
import {
  LeaderboardWindow,
  useLeaderboard,
} from '@/services/use-leaderboard';

function formatTokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`;
  return `${n}`;
}

function relativeTime(iso: string): string {
  const ms = Date.now() - new Date(iso).getTime();
  if (!Number.isFinite(ms) || ms < 0) return '—';
  const min = Math.floor(ms / 60_000);
  if (min < 1) return 'just now';
  if (min < 60) return `${min}m ago`;
  const h = Math.floor(min / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  return `${d}d ago`;
}

const TABS: { value: LeaderboardWindow; label: string }[] = [
  { value: '5h', label: 'Current period' },
  { value: '24h', label: 'Last 24h' },
  { value: '7d', label: 'Last 7d' },
  { value: 'all', label: 'All time' },
];

export default function Leaderboard() {
  const [windowSel, setWindowSel] = useState<LeaderboardWindow>('5h');
  const { rows, loading, error } = useLeaderboard(windowSel);

  return (
    <section className="mt-10 w-full max-w-2xl mx-auto">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-lg font-semibold text-slate-900">Token leaderboard</h2>
        <div className="inline-flex rounded-lg border border-slate-200 bg-white p-0.5 text-xs">
          {TABS.map((t) => (
            <button
              key={t.value}
              onClick={() => setWindowSel(t.value)}
              className={`rounded-md px-3 py-1 transition ${
                windowSel === t.value
                  ? 'bg-slate-900 text-white'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>

      <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
        {loading && rows.length === 0 && (
          <div className="p-6 text-center text-sm text-slate-500">Loading...</div>
        )}

        {!loading && error && (
          <div className="p-6 text-center text-sm text-red-500">{error}</div>
        )}

        {!loading && !error && rows.length === 0 && (
          <div className="p-6 text-center text-sm text-slate-500">
            No token usage recorded yet. Open a Claude Code session with the
            plugin enabled to start tracking.
          </div>
        )}

        {rows.length > 0 && (
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
              <tr>
                <th className="px-4 py-2 text-left">#</th>
                <th className="px-4 py-2 text-left">Seat</th>
                <th className="px-4 py-2 text-right">Total tokens</th>
                <th className="px-4 py-2 text-right">Sessions</th>
                <th className="px-4 py-2 text-right">Last active</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {rows.map((row, idx) => (
                <tr key={row.seat_id} className="hover:bg-slate-50">
                  <td className="px-4 py-2 text-slate-400">{idx + 1}</td>
                  <td className="px-4 py-2 font-medium text-slate-900">
                    {row.title}
                  </td>
                  <td
                    className="px-4 py-2 text-right font-mono text-slate-900"
                    title={`in ${row.input_tokens.toLocaleString()} · out ${row.output_tokens.toLocaleString()}`}
                  >
                    {formatTokens(row.total_tokens)}
                  </td>
                  <td className="px-4 py-2 text-right text-slate-600">
                    {row.session_count}
                  </td>
                  <td className="px-4 py-2 text-right text-slate-500">
                    {relativeTime(row.last_active_at)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
