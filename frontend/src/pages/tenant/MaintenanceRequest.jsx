import { useState, useEffect } from "react";
import { getTickets, createTicket } from "../../api/maintenance";
import { getLeases } from "../../api/leases";
import Navbar from "../../components/Navbar";
import StatusBadge from "../../components/shared/StatusBadge";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

const PRIORITY_INFO = {
  routine:   { icon: "🔧", desc: "Non-urgent repairs, scheduled during normal maintenance hours" },
  urgent:    { icon: "⚠️", desc: "Significant issue affecting daily operations, address within 24-48 hours" },
  emergency: { icon: "🚨", desc: "Immediate safety risk or severe property damage — triggers instant alert" },
};

export default function MaintenanceRequest() {
  const [tickets, setTickets]   = useState([]);
  const [leases, setLeases]     = useState([]);
  const [form, setForm]         = useState({ description: "", priority: "routine", lease_id: "" });
  const [loading, setLoading]   = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage]   = useState("");
  const [error, setError]       = useState("");

  const load = () => {
    setLoading(true);
    Promise.all([getTickets(), getLeases({ status: "active" })])
      .then(([ticketsRes, leasesRes]) => {
        const activeLeases = leasesRes.data || [];
        setTickets(ticketsRes.data || []);
        setLeases(activeLeases);
        // Auto-select if user has exactly one active lease.
        if (activeLeases.length === 1) {
          setForm((prev) => ({ ...prev, lease_id: String(activeLeases[0].id) }));
        }
      })
      .finally(() => setLoading(false));
  };
  useEffect(() => { load(); }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    if (!form.description.trim()) { setError("Please describe the issue."); return; }
    if (leases.length > 1 && !form.lease_id) {
      setError("Please select which leased unit this request is for.");
      return;
    }
    setSubmitting(true);
    try {
      const payload = { description: form.description, priority: form.priority };
      if (form.lease_id) payload.lease_id = Number(form.lease_id);
      await createTicket(payload);
      setMessage("Maintenance request submitted! Our team will review it shortly.");
      setForm((prev) => ({ ...prev, description: "", priority: "routine" }));
      load();
    } catch (err) {
      setError(err.response?.data?.error || "Submission failed. Do you have an active lease?");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Navbar />
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-6">Maintenance Requests</h1>

        {message && (
          <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg text-green-700 text-sm flex justify-between">
            {message}
            <button onClick={() => setMessage("")} className="ml-4">✕</button>
          </div>
        )}

        {/* Submit New Request */}
        <div className="card mb-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Submit New Request</h2>
          {error && <div className="mb-3 p-3 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">{error}</div>}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="form-label">Leased Unit</label>
              <select
                className="form-select"
                value={form.lease_id}
                onChange={(e) => setForm({ ...form, lease_id: e.target.value })}
                disabled={leases.length === 0 || leases.length === 1}
                required={leases.length > 1}
              >
                {leases.length > 1 && <option value="">Select lease</option>}
                {leases.map((lease) => (
                  <option key={lease.id} value={lease.id}>
                    Lease #{lease.id} - Unit {lease.unit_number || lease.unit_id}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="form-label">Priority Level</label>
              <div className="grid grid-cols-3 gap-3">
                {Object.entries(PRIORITY_INFO).map(([key, info]) => (
                  <button key={key} type="button"
                    onClick={() => setForm({ ...form, priority: key })}
                    className={`p-3 rounded-xl border-2 text-left transition-all ${
                      form.priority === key
                        ? key === "emergency" ? "border-red-500 bg-red-50"
                          : key === "urgent" ? "border-orange-500 bg-orange-50"
                          : "border-blue-500 bg-blue-50"
                        : "border-gray-200 hover:border-gray-300"
                    }`}>
                    <div className="text-xl mb-1">{info.icon}</div>
                    <div className="text-sm font-semibold capitalize text-gray-900">{key}</div>
                    <div className="text-xs text-gray-500 mt-0.5 line-clamp-2">{info.desc}</div>
                  </button>
                ))}
              </div>
            </div>
            <div>
              <label className="form-label">Description</label>
              <textarea className="form-input" rows={4}
                placeholder="Please describe the issue in detail (location, nature of problem, any safety concerns)..."
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })} />
            </div>
            <button type="submit" className="btn-primary" disabled={submitting}>
              {submitting ? "Submitting..." : "Submit Request"}
            </button>
          </form>
        </div>

        {/* Existing Tickets */}
        <div className="card">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">My Requests</h2>
          {loading ? <LoadingSpinner size="sm" /> : (
            tickets.length === 0 ? (
              <p className="text-gray-500 text-sm text-center py-8">No maintenance requests yet</p>
            ) : (
              <div className="space-y-3">
                {tickets.map((t) => (
                  <div key={t.id} className="flex items-start justify-between p-4 bg-gray-50 rounded-xl">
                    <div className="flex items-start gap-3">
                      <span className="text-xl">{PRIORITY_INFO[t.priority]?.icon || "🔧"}</span>
                      <div>
                        <p className="text-sm font-medium text-gray-900">{t.description}</p>
                        <p className="text-xs text-gray-500 mt-0.5">
                          Ticket #{t.id} · {new Date(t.created_at).toLocaleDateString()}
                          {t.is_tenant_caused && t.billing_amount > 0 && (
                            <span className="ml-2 text-red-600 font-medium">· Billed ${t.billing_amount}</span>
                          )}
                        </p>
                      </div>
                    </div>
                    <div className="flex flex-col items-end gap-1">
                      <StatusBadge status={t.status} />
                      <StatusBadge status={t.priority} />
                    </div>
                  </div>
                ))}
              </div>
            )
          )}
        </div>
      </div>
    </>
  );
}
