import { useState, useEffect } from "react";
import { getApplications, approveApplication, rejectApplication } from "../../api/applications";
import Navbar from "../../components/Navbar";
import StatusBadge from "../../components/shared/StatusBadge";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

export default function ApplicationsList() {
  const [apps, setApps]         = useState([]);
  const [filter, setFilter]     = useState("pending");
  const [loading, setLoading]   = useState(true);
  const [selected, setSelected] = useState(null);
  const [approveForm, setApproveForm] = useState({ start_date: "", end_date: "", rent_amount: "", payment_cycle: "monthly" });
  const [rejectReason, setRejectReason] = useState("");
  const [modal, setModal]       = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage]   = useState("");

  const load = () => {
    setLoading(true);
    getApplications(filter ? { status: filter } : {})
      .then((r) => setApps(r.data))
      .finally(() => setLoading(false));
  };
  useEffect(() => { load(); }, [filter]); // eslint-disable-line

  const handleApprove = async () => {
    setSubmitting(true);
    try {
      await approveApplication(selected.id, approveForm);
      setMessage(`Application #${selected.id} approved and lease created.`);
      setModal(null);
      load();
    } catch (err) {
      setMessage(err.response?.data?.error || "Approval failed.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleReject = async () => {
    setSubmitting(true);
    try {
      await rejectApplication(selected.id, { reason: rejectReason });
      setMessage(`Application #${selected.id} rejected.`);
      setModal(null);
      load();
    } catch (err) {
      setMessage(err.response?.data?.error || "Rejection failed.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Navbar />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-6">Lease Applications</h1>

        {message && (
          <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg text-green-700 text-sm flex justify-between">
            {message}<button onClick={() => setMessage("")} className="ml-4">✕</button>
          </div>
        )}

        {/* Filter tabs */}
        <div className="flex gap-2 mb-4">
          {["pending", "under_review", "approved", "rejected", ""].map((s) => (
            <button key={s || "all"} onClick={() => setFilter(s)}
              className={`px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
                filter === s ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}>
              {s ? s.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase()) : "All"}
            </button>
          ))}
        </div>

        {loading ? <LoadingSpinner /> : (
          <div className="card">
            <table className="w-full">
              <thead className="border-b border-gray-200">
                <tr>
                  <th className="table-header">ID</th>
                  <th className="table-header">Unit</th>
                  <th className="table-header">Date</th>
                  <th className="table-header">Business</th>
                  <th className="table-header">Status</th>
                  <th className="table-header"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {apps.length === 0 ? (
                  <tr><td colSpan={6} className="py-12 text-center text-gray-500">No applications found</td></tr>
                ) : apps.map((app) => (
                  <tr key={app.id} className="hover:bg-gray-50">
                    <td className="table-cell font-medium">#{app.id}</td>
                    <td className="table-cell">{app.unit_number || `Unit #${app.unit_id}`}</td>
                    <td className="table-cell">{app.application_date}</td>
                    <td className="table-cell">{app.application_data?.business_type || "—"}</td>
                    <td className="table-cell"><StatusBadge status={app.status} /></td>
                    <td className="table-cell">
                      {["pending", "under_review"].includes(app.status) && (
                        <div className="flex gap-2">
                          <button onClick={() => { setSelected(app); setModal("approve"); setApproveForm({ start_date: "", end_date: "", rent_amount: "", payment_cycle: "monthly" }); }}
                            className="btn-success text-xs py-1 px-2">Approve</button>
                          <button onClick={() => { setSelected(app); setModal("reject"); setRejectReason(""); }}
                            className="btn-danger text-xs py-1 px-2">Reject</button>
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Approve Modal */}
        {modal === "approve" && selected && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
              <h3 className="text-lg font-semibold mb-1">Approve Application #{selected.id}</h3>
              <p className="text-sm text-gray-500 mb-4">Create lease for Unit {selected.unit_number}</p>

              {selected.employment_info && (
                <div className="mb-4 p-3 bg-blue-50 rounded-lg text-sm text-blue-800">
                  <strong>Business Info:</strong> {selected.employment_info}
                </div>
              )}

              <div className="space-y-3">
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="form-label">Start Date</label>
                    <input type="date" className="form-input" value={approveForm.start_date}
                      onChange={(e) => setApproveForm({ ...approveForm, start_date: e.target.value })} />
                  </div>
                  <div>
                    <label className="form-label">End Date</label>
                    <input type="date" className="form-input" value={approveForm.end_date}
                      onChange={(e) => setApproveForm({ ...approveForm, end_date: e.target.value })} />
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="form-label">Monthly Rent ($)</label>
                    <input type="number" className="form-input" placeholder="2500"
                      value={approveForm.rent_amount}
                      onChange={(e) => setApproveForm({ ...approveForm, rent_amount: e.target.value })} />
                  </div>
                  <div>
                    <label className="form-label">Payment Cycle</label>
                    <select className="form-select" value={approveForm.payment_cycle}
                      onChange={(e) => setApproveForm({ ...approveForm, payment_cycle: e.target.value })}>
                      <option value="monthly">Monthly</option>
                      <option value="quarterly">Quarterly</option>
                      <option value="biannual">Bi-Annual</option>
                      <option value="annual">Annual</option>
                    </select>
                  </div>
                </div>
              </div>
              <div className="flex gap-2 mt-5">
                <button className="btn-secondary flex-1" onClick={() => setModal(null)}>Cancel</button>
                <button className="btn-success flex-1" onClick={handleApprove} disabled={submitting}>
                  {submitting ? "Approving..." : "Approve & Create Lease"}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Reject Modal */}
        {modal === "reject" && selected && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
              <h3 className="text-lg font-semibold mb-4">Reject Application #{selected.id}</h3>
              <div>
                <label className="form-label">Reason for Rejection</label>
                <textarea className="form-input" rows={3} placeholder="Please provide a reason..."
                  value={rejectReason} onChange={(e) => setRejectReason(e.target.value)} />
              </div>
              <div className="flex gap-2 mt-4">
                <button className="btn-secondary flex-1" onClick={() => setModal(null)}>Cancel</button>
                <button className="btn-danger flex-1" onClick={handleReject} disabled={submitting}>
                  {submitting ? "Rejecting..." : "Confirm Rejection"}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  );
}
