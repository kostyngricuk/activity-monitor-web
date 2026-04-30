'use client';

import { useEffect, useRef, useState } from 'react';

type Props = {
  seatTitle: string;
  onClose: () => void;
  onSubmit: (currentPassword: string) => Promise<string | null>;
};

export default function DeleteSeatModal({ seatTitle, onClose, onSubmit }: Props) {
  const [currentPassword, setCurrentPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!currentPassword) {
      setError('Password is required.');
      return;
    }
    setLoading(true);
    const err = await onSubmit(currentPassword);
    setLoading(false);
    if (err) setError(err);
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="w-full max-w-md mx-4 rounded-2xl bg-white shadow-2xl p-6 sm:p-8"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-5">
          <h2 className="text-xl font-semibold text-slate-900">Remove Seat</h2>
          <p className="mt-1 text-sm text-slate-500">
            Confirm the password to permanently remove{' '}
            <span className="font-semibold text-slate-700">{seatTitle}</span>. This
            action cannot be undone.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-medium text-slate-600 mb-1.5">
              Current Password
            </label>
            <input
              ref={inputRef}
              type="password"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              className="w-full rounded-lg border border-slate-200 bg-slate-50 px-3.5 py-2.5 text-sm text-slate-900 outline-none focus:border-red-500 focus:bg-white focus:ring-2 focus:ring-red-500/20"
              autoComplete="off"
            />
          </div>

          {error && <p className="text-xs text-red-600">{error}</p>}

          <div className="flex gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 rounded-lg border border-slate-200 bg-white px-4 py-2.5 text-sm font-medium text-slate-700 hover:bg-slate-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading || !currentPassword}
              className="flex-1 rounded-lg bg-red-500 px-4 py-2.5 text-sm font-medium text-white hover:bg-red-600 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {loading ? 'Removing...' : 'Remove Seat'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
