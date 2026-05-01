'use client';

import { useState } from 'react';
import { Seat, deleteSeat, updateSeat } from '@/services/seats';
import { useSeats } from '@/services/use-seats';
import DeleteSeatModal from './DeleteSeatModal';
import EditSeatModal from './EditSeatModal';
import SeatListHeader from './SeatListHeader';
import StatCard from './StatCard';
import SeatRow from './SeatRow';

type SeatTarget = { seat: Seat };

export default function SeatList() {
  const { seats, loading, connected, removeSeatLocal } = useSeats();
  const [editTarget, setEditTarget] = useState<SeatTarget | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<SeatTarget | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const copySeatId = async (seatId: string) => {
    try {
      await navigator.clipboard.writeText(seatId);
    } catch {
      return;
    }
    setCopiedId(seatId);
    setTimeout(
      () => setCopiedId((current) => (current === seatId ? null : current)),
      1500
    );
  };

  const handleEdit = async (
    currentPassword: string,
    newTitle: string
  ): Promise<string | null> => {
    if (!editTarget) return 'No seat selected';
    const err = await updateSeat(editTarget.seat.id, currentPassword, newTitle);
    if (err) return err;
    setEditTarget(null);
    return null;
  };

  const handleDelete = async (currentPassword: string): Promise<string | null> => {
    if (!deleteTarget) return 'No seat selected';
    const err = await deleteSeat(deleteTarget.seat.id, currentPassword);
    if (err) return err;
    removeSeatLocal(deleteTarget.seat.id);
    setDeleteTarget(null);
    return null;
  };

  const busyCount = seats.filter((s) => s.status === 'busy').length;
  const totalCount = seats.length;
  const totalSessions = seats.reduce((sum, s) => sum + (s.session_count ?? 0), 0);

  return (
    <div className="w-full max-w-2xl mx-auto">
      <SeatListHeader connected={connected} />

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-6">
        <StatCard label="Total" value={totalCount} accent="blue" />
        <StatCard label="Active Sessions" value={totalSessions} accent="emerald" />
        <StatCard label="Disabled" value={totalCount - busyCount} accent="slate" />
      </div>

      <div className="space-y-3">
        {loading && (
          <div className="rounded-xl border border-slate-200 bg-white p-6 text-center text-sm text-slate-500">
            Loading seats...
          </div>
        )}

        {!loading && seats.length === 0 && (
          <div className="rounded-xl border border-dashed border-slate-300 bg-white p-8 text-center text-sm text-slate-500">
            No seats yet. Install the Activity Monitor Claude Code plugin and run /activity-monitor:setup to register one.
          </div>
        )}

        {seats.map((seat) => (
          <SeatRow
            key={seat.id}
            seat={seat}
            copiedId={copiedId}
            onCopyId={copySeatId}
            onEdit={(s) => setEditTarget({ seat: s })}
            onDelete={(s) => setDeleteTarget({ seat: s })}
          />
        ))}
      </div>

      {editTarget && (
        <EditSeatModal
          seatTitle={editTarget.seat.title}
          onClose={() => setEditTarget(null)}
          onSubmit={handleEdit}
        />
      )}

      {deleteTarget && (
        <DeleteSeatModal
          seatTitle={deleteTarget.seat.title}
          onClose={() => setDeleteTarget(null)}
          onSubmit={handleDelete}
        />
      )}
    </div>
  );
}
