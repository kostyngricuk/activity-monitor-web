'use client';

type Accent = 'emerald' | 'blue' | 'slate';

type Props = {
  label: string;
  value: number;
  accent?: Accent;
};

export default function StatCard({ label, value, accent }: Props) {
  const accentClass =
    accent === 'emerald'
      ? 'text-emerald-600'
      : accent === 'blue'
      ? 'text-blue-600'
      : accent === 'slate'
      ? 'text-slate-400'
      : 'text-slate-900';
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4">
      <div className="text-xs font-medium uppercase tracking-wide text-slate-500">
        {label}
      </div>
      <div className={`mt-1 text-2xl font-semibold ${accentClass}`}>{value}</div>
    </div>
  );
}
