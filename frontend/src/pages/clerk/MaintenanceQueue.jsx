import { useState, useEffect } from "react";
import { getTickets, updateTicket, billDamage } from "../../api/maintenance";
import Navbar from "../../components/Navbar";
import StatusBadge from "../../components/shared/StatusBadge";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

const PRIORITY_ICONS = { emergency: "🚨", urgent: "⚠️", routine: "🔧" };

export default function MaintenanceQueue() {
  const [tickets, setTickets]   = useState([]);
  const [loading, setLoading]   = useState(true);
  const [selected, setSelected] = useState(null);
  const [modal, setModal]       = useState(null); // "update" | "bill"
  const [newStatus, setNewStatus] = useState("");
  const [billAmount, setBillAmount] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage]   = useState("");

  const load = () => {
    getTickets().then((r) => setTickets(r.data)).finally(() => setLoading(false));
  };
  useEffect(() => { load(); }, []);

  const handleUpdate = async () => {
    setSubmitting(true);
    try {
      await updateTicket(selected.id, { status: newStatus });
      setMessage(`Ticket #${selected.id} updated to ${newStatus}`);
      setModal(null);
      load();
    } catch (err) {
      setMessage(err.response?.data?.error || "Update failed.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleBill = async () => {
    if (!billAmount || parseFloat(billAmount) <= 0) return;
    setSubmitting(true);
    try {
      await billDamage(selected.id, { amount: parseFloat(billAmount) });
      setMessage(`Invoice of $${billAmount} created for Ticket #${selected.id}`);
      setModal(null);
      load();
    } catch (err) {
      setMessage(err.response?.data?.error || "Billing failed.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Navbar />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Maintenance Queue</h1>
        <p className="text-gray-500 mb-6 text-sm">Prioritized: Emergency → Urgent → Routine (FCFS within same priority)</p>

        {message && (
          <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg text-green-700 text-sm flex justify-between">
            {message}<button onClick={() => setMessage("")} className="ml-4">✕</button>
          </div>
        )}

        {loading ? <LoadingSpinner /> : (
          <div className="space-y-3">
            {tickets.length === 0 ? (
              <div className="card text-center py-12 text-gray-500">
                <p className="text-4xl mb-3">✅</p>
                <p className="font-medium">No active maintenance tickets</p>
              </div>
            ) : tickets.map((t, idx) => (
              <div key={t.id} className={`card flex items-start justify-between ${
                t.priority === "emergency" ? "border-red-300 bg-red-50" : t.priority === "urgent" ? "border-orange-300 bg-orange-50" : ""
              }`}>
                <div className="flex items-start gap-3">
                  <div className="flex-shrink-0 w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center text-sm font-bold text-gray-600">
                    {idx + 1}
                  </div>
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span>{PRIORITY_ICONS[t.priority]}</span>
                      <span className="font-semibold text-gray-900 text-sm">Ticket #{t.id}</span>
                      <StatusBadge status={t.priority} />
                      <StatusBadge status={t.status} />
                    </div>
                    <p className="text-sm text-gray-700">{t.description}</p>
                    <p className="text-xs text-gray-500 mt-1">
                      Unit #{t.unit_id} · {new Date(t.created_at).toLocaleString()}
                      {t.is_tenant_caused && <span className="ml-2 text-red-600 font-medium">· Tenant-caused</span>}
                    </p>
                  </div>
                </div>
                <div className="flex gap-2 ml-4 flex-shrink-0">
                  <button onClick={() => { setSelected(t); setNewStatus(t.status); setModal("update"); }}
                    className="btn-secondary text-xs py-1.5 px-3">Update</button>
                  {!t.is_tenant_caused && (
                    <button onClick={() => { setSelected(t); setBillAmount(""); setModal("bill"); }}
                      className="btn-danger text-xs py-1.5 px-3">Bill Damage</button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Update Status Modal */}
        {modal === "update" && selected && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl p-6 w-full max-w-sm shadow-2xl">
              <h3 className="text-lg font-semibold mb-4">Update Ticket #{selected.id}</h3>
              <div>
                <label className="form-label">New Status</label>
                <select className="form-select" value={newStatus} onChange={(e) => setNewStatus(e.target.value)}>
                  <option value="open">Open</option>
                  <option value="in_progress">In Progress</option>
                  <option value="completed">Completed</option>
                  <option value="cancelled">Cancelled</option>
                </select>
              </div>
              <div className="flex gap-2 mt-4">
                <button className="btn-secondary flex-1" onClick={() => setModal(null)}>Cancel</button>
                <button className="btn-primary flex-1" onClick={handleUpdate} disabled={submitting}>
                  {submitting ? "Updating..." : "Save"}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Bill Damage Modal */}
        {modal === "bill" && selected && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl p-6 w-full max-w-sm shadow-2xl">
              <h3 className="text-lg font-semibold mb-1">Bill Tenant for Damage</h3>
              <p className="text-sm text-gray-500 mb-4">Ticket #{selected.id}: {selected.description}</p>
              <div>
                <label className="form-label">Repair Cost ($)</label>
                <input type="number" className="form-input" placeholder="0.00"
                  value={billAmount} onChange={(e) => setBillAmount(e.target.value)} />
              </div>
              <div className="flex gap-2 mt-4">
                <button className="btn-secondary flex-1" onClick={() => setModal(null)}>Cancel</button>
                <button className="btn-danger flex-1" onClick={handleBill} disabled={submitting}>
                  {submitting ? "Billing..." : "Create Invoice"}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  );
}
