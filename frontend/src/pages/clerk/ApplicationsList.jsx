import { useState, useEffect } from "react";
import { getApplications, approveApplication, rejectApplication } from "../../api/applications";
import { getAppointments, updateAppointment } from "../../api/appointments";
import { getLeases, updateLease, sendLeaseAgreement } from "../../api/leases";
import { useAuth } from "../../context/AuthContext";
import Navbar from "../../components/Navbar";
import StatusBadge from "../../components/shared/StatusBadge";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

export default function ApplicationsList() {
  const { user } = useAuth();
  const [apps, setApps]         = useState([]);
  const [filter, setFilter]     = useState("pending");
  const [loading, setLoading]   = useState(true);
  const [selected, setSelected] = useState(null);
  const [approveForm, setApproveForm] = useState({ start_date: "", end_date: "", rent_amount: "", payment_cycle: "monthly", auto_renew: false });
  const [modal, setModal]       = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage]   = useState("");
  const [viewings, setViewings] = useState([]);
  const [viewingFilter, setViewingFilter] = useState("pending");
  const [leases, setLeases] = useState([]);
  const [leaseModal, setLeaseModal] = useState(null);
  const [leaseForm, setLeaseForm] = useState({ end_date: "", auto_renew: false });

  const load = () => {
    setLoading(true);
    getApplications(filter ? { status: filter } : {})
      .then((r) => setApps(r.data))
      .finally(() => setLoading(false));
  };
  useEffect(() => { load(); }, [filter]); // eslint-disable-line react-hooks/exhaustive-deps

  const loadViewings = () => {
    getAppointments(viewingFilter ? { status: viewingFilter } : {})
      .then((r) => setViewings(r.data || []))
      .catch(() => setViewings([]));
  };
  useEffect(() => { loadViewings(); }, [viewingFilter]); // eslint-disable-line react-hooks/exhaustive-deps

  const loadLeases = () => {
    getLeases({ status: "active" })
      .then((r) => setLeases(r.data || []))
      .catch(() => setLeases([]));
  };
  useEffect(() => { loadLeases(); }, []);

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

  const handleReject = async (app) => {
    setSubmitting(true);
    try {
      await rejectApplication(app.id, {});
      setMessage(`Application #${app.id} rejected.`);
      load();
    } catch (err) {
      setMessage(err.response?.data?.error || "Rejection failed. Make sure you are logged in as Clerk or Admin.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleViewingDecision = async (viewing, status) => {
    setSubmitting(true);
    try {
      await updateAppointment(viewing.id, { status });
      setMessage(`Viewing #${viewing.id} ${status === "confirmed" ? "approved" : "rejected"}.`);
      loadViewings();
    } catch (err) {
      setMessage(err.response?.data?.error || "Viewing update failed.");
    } finally {
      setSubmitting(false);
    }
  };

  const openLeaseModal = (lease) => {
    setLeaseModal(lease);
    setLeaseForm({
      end_date: lease.end_date || "",
      auto_renew: Boolean(lease.auto_renew),
    });
  };

  const handleSaveLeaseTerms = async () => {
    if (!leaseModal) return;
    setSubmitting(true);
    try {
      await updateLease(leaseModal.id, leaseForm);
      setMessage(`Lease #${leaseModal.id} updated.`);
      setLeaseModal(null);
      loadLeases();
    } catch (err) {
      setMessage(err.response?.data?.error || "Lease update failed.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleTerminateLease = async (lease) => {
    setSubmitting(true);
    try {
      await updateLease(lease.id, { status: "terminated" });
      setMessage(`Lease #${lease.id} terminated.`);
      loadLeases();
    } catch (err) {
      setMessage(err.response?.data?.error || "Lease termination failed.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleSendAgreement = async (lease) => {
    setSubmitting(true);
    try {
      await sendLeaseAgreement(lease.id);
      setMessage(`Lease agreement sent for lease #${lease.id}.`);
      loadLeases();
    } catch (err) {
      setMessage(err.response?.data?.error || "Could not send lease agreement.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Navbar />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-6">Tenants</h1>

        {message && (
          <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg text-green-700 text-sm flex justify-between">
            {message}<button onClick={() => setMessage("")} className="ml-4">✕</button>
          </div>
        )}

        {/* Filter tabs */}
        <div className="flex gap-2 mb-4">
          {["pending", "approved", "rejected", ""].map((s) => (
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
                        user?.role === "admin" ? (
                          <div className="flex gap-2">
                            <button
                              onClick={() => { setSelected(app); setModal("approve"); setApproveForm({ start_date: "", end_date: "", rent_amount: "", payment_cycle: "monthly", auto_renew: false }); }}
                              className="btn-success text-xs py-1 px-2"
                            >
                              Approve
                            </button>
                            <button
                              onClick={() => handleReject(app)}
                              className="btn-danger text-xs py-1 px-2"
                            >
                              Reject
                            </button>
                          </div>
                        ) : (
                          <span className="text-xs text-gray-400 px-2 py-1">Admin only</span>
                        )
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        <div className="mt-8">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Active Leases</h2>
          <div className="card">
            <div className="overflow-x-auto">
            <table className="w-full min-w-[980px]">
              <thead className="border-b border-gray-200">
                <tr>
                  <th className="table-header">Lease</th>
                  <th className="table-header">Tenant</th>
                  <th className="table-header">Unit</th>
                  <th className="table-header">Start</th>
                  <th className="table-header">End</th>
                  <th className="table-header">Auto Renew</th>
                  <th className="table-header">Agreement Signed</th>
                  <th className="table-header"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {leases.length === 0 ? (
                  <tr><td colSpan={8} className="py-12 text-center text-gray-500">No active leases found</td></tr>
                ) : leases.map((l) => (
                  <tr key={l.id} className="hover:bg-gray-50">
                    <td className="table-cell font-medium">#{l.id}</td>
                    <td className="table-cell">{l.tenant_name || `Tenant #${l.tenant_id}`}</td>
                    <td className="table-cell">{l.unit_number || `Unit #${l.unit_id}`}</td>
                    <td className="table-cell">{l.start_date}</td>
                    <td className="table-cell">{l.end_date}</td>
                    <td className="table-cell">{l.auto_renew ? "On" : "Off"}</td>
                    <td className="table-cell">{l.agreement_signed ? "Yes" : "No"}</td>
                    <td className="table-cell">
                      <div className="flex gap-2">
                        {user?.role === "admin" ? (
                          <button className="btn-secondary text-xs py-1 px-2" onClick={() => openLeaseModal(l)}>
                            Edit Terms
                          </button>
                        ) : (
                          <span className="text-xs text-gray-400 px-2 py-1">Admin only</span>
                        )}
                        {l.agreement_signed ? (
                          <span className="text-xs text-gray-400 px-2 py-1">Signed</span>
                        ) : (
                          <button className="btn-secondary text-xs py-1 px-2" onClick={() => handleSendAgreement(l)} disabled={submitting || l.agreement_status === "sent"}>
                            {l.agreement_status === "sent" ? "Sent" : "Send Agreement"}
                          </button>
                        )}
                        {user?.role === "admin" && (
                          <button className="btn-danger text-xs py-1 px-2" onClick={() => handleTerminateLease(l)} disabled={submitting}>
                            Terminate
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            </div>
          </div>
        </div>

        <div className="mt-8">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Viewing Requests</h2>
          <div className="flex gap-2 mb-4">
            {["pending", "confirmed", "rejected", ""].map((s) => (
              <button key={s || "all"} onClick={() => setViewingFilter(s)}
                className={`px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
                  viewingFilter === s ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
                }`}>
                {s ? s.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase()) : "All"}
              </button>
            ))}
          </div>

          <div className="card">
            <table className="w-full">
              <thead className="border-b border-gray-200">
                <tr>
                  <th className="table-header">ID</th>
                  <th className="table-header">Tenant</th>
                  <th className="table-header">Unit</th>
                  <th className="table-header">Scheduled Time</th>
                  <th className="table-header">Status</th>
                  <th className="table-header"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {viewings.length === 0 ? (
                  <tr><td colSpan={6} className="py-12 text-center text-gray-500">No viewing requests found</td></tr>
                ) : viewings.map((v) => (
                  <tr key={v.id} className="hover:bg-gray-50">
                    <td className="table-cell font-medium">#{v.id}</td>
                    <td className="table-cell">{v.tenant_name || `Tenant #${v.tenant_id}`}</td>
                    <td className="table-cell">{v.unit_number || `Unit #${v.unit_id}`}</td>
                    <td className="table-cell">{new Date(v.scheduled_time).toLocaleString()}</td>
                    <td className="table-cell"><StatusBadge status={v.status} /></td>
                    <td className="table-cell">
                      {v.status === "pending" && (
                        <div className="flex gap-2">
                          <button
                            onClick={() => handleViewingDecision(v, "confirmed")}
                            disabled={submitting}
                            className="btn-success text-xs py-1 px-2"
                          >
                            Approve
                          </button>
                          <button
                            onClick={() => handleViewingDecision(v, "rejected")}
                            disabled={submitting}
                            className="btn-danger text-xs py-1 px-2"
                          >
                            Reject
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

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
                <div>
                  <label className="inline-flex items-center gap-2 text-sm text-gray-700">
                    <input
                      type="checkbox"
                      checked={approveForm.auto_renew}
                      onChange={(e) => setApproveForm({ ...approveForm, auto_renew: e.target.checked })}
                    />
                    Auto renew lease
                  </label>
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

        {leaseModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
              <h3 className="text-lg font-semibold mb-4">Edit Lease Terms #{leaseModal.id}</h3>
              <div className="space-y-3">
                <div>
                  <label className="form-label">End Date</label>
                  <input
                    type="date"
                    className="form-input"
                    value={leaseForm.end_date}
                    onChange={(e) => setLeaseForm({ ...leaseForm, end_date: e.target.value })}
                  />
                </div>
                <div>
                  <label className="inline-flex items-center gap-2 text-sm text-gray-700">
                    <input
                      type="checkbox"
                      checked={leaseForm.auto_renew}
                      onChange={(e) => setLeaseForm({ ...leaseForm, auto_renew: e.target.checked })}
                    />
                    Auto renew lease
                  </label>
                </div>
              </div>
              <div className="flex gap-2 mt-5">
                <button className="btn-secondary flex-1" onClick={() => setLeaseModal(null)}>Cancel</button>
                <button className="btn-success flex-1" onClick={handleSaveLeaseTerms} disabled={submitting}>
                  {submitting ? "Saving..." : "Save Terms"}
                </button>
              </div>
            </div>
          </div>
        )}

      </div>
    </>
  );
}
