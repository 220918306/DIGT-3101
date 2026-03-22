import { useState, useEffect } from "react";
import { getInvoices, generateInvoices, updateInvoiceUtilities } from "../../api/invoices";
import Navbar from "../../components/Navbar";
import StatusBadge from "../../components/shared/StatusBadge";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

const VIEW_INVOICES = "invoices";
const VIEW_UTILITIES = "utilities";

export default function InvoiceManagement() {
  const [invoices, setInvoices]   = useState([]);
  const [filter, setFilter]       = useState("");
  const [view, setView]           = useState(VIEW_INVOICES);
  const [loading, setLoading]     = useState(true);
  const [generating, setGenerating] = useState(false);
  const [message, setMessage]     = useState("");
  const [utilityModal, setUtilityModal] = useState(null);
  const [utilityForm, setUtilityForm] = useState({ electricity: "", water: "", waste: "" });
  const [savingUtilities, setSavingUtilities] = useState(false);
  const [utilityError, setUtilityError] = useState("");

  const load = () => {
    setLoading(true);
    getInvoices(filter ? { status: filter } : {})
      .then((r) => setInvoices(r.data))
      .finally(() => setLoading(false));
  };
  useEffect(() => { load(); }, [filter]); // eslint-disable-line

  const handleGenerate = async () => {
    setGenerating(true);
    try {
      const r = await generateInvoices();
      setMessage(r.data.message);
      load();
    } catch (err) {
      setMessage(err.response?.data?.error || "Generation failed.");
    } finally {
      setGenerating(false);
    }
  };

  const openUtilityEditor = (inv) => {
    if (!inv.utilities_editable) return;
    setUtilityError("");
    setUtilityModal(inv);
    setUtilityForm({
      electricity: inv.utility_electricity != null ? String(inv.utility_electricity) : "0",
      water:       inv.utility_water != null ? String(inv.utility_water) : "0",
      waste:       inv.utility_waste != null ? String(inv.utility_waste) : "0",
    });
  };

  const saveUtilities = async () => {
    if (!utilityModal) return;
    setUtilityError("");
    setSavingUtilities(true);
    try {
      const body = {
        electricity: parseFloat(utilityForm.electricity),
        water:       parseFloat(utilityForm.water),
        waste:       parseFloat(utilityForm.waste),
      };
      if ([body.electricity, body.water, body.waste].some((n) => Number.isNaN(n) || n < 0)) {
        setUtilityError("Enter valid amounts (zero or greater).");
        setSavingUtilities(false);
        return;
      }
      await updateInvoiceUtilities(utilityModal.id, body);
      setUtilityModal(null);
      setMessage("Utility charges updated. Invoice total recalculated.");
      load();
    } catch (err) {
      const data = err.response?.data;
      setUtilityError(data?.error || data?.errors?.join?.(", ") || "Could not update utilities.");
    } finally {
      setSavingUtilities(false);
    }
  };

  const totalRevenue = invoices.filter((i) => i.status === "paid").reduce((s, i) => s + parseFloat(i.amount_paid || 0), 0);
  const pendingAmount = invoices.filter((i) => i.status !== "paid").reduce((s, i) => s + parseFloat(i.remaining || 0), 0);

  const utilityRows = invoices.filter((i) => i.utilities_editable);
  const showUtilityColumns = view === VIEW_UTILITIES;

  return (
    <>
      <Navbar />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Invoice Management</h1>
          <button onClick={handleGenerate} disabled={generating} className="btn-primary shrink-0">
            {generating ? "Generating..." : "⚡ Generate Monthly Invoices"}
          </button>
        </div>

        {message && (
          <div className="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-lg text-blue-700 text-sm flex justify-between">
            {message}<button type="button" onClick={() => setMessage("")} className="ml-4">✕</button>
          </div>
        )}

        {/* Summary */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <div className="card border-l-4 border-green-500">
            <p className="text-sm text-gray-500">Collected Revenue (filtered)</p>
            <p className="text-2xl font-bold text-green-600">${totalRevenue.toFixed(2)}</p>
          </div>
          <div className="card border-l-4 border-yellow-500">
            <p className="text-sm text-gray-500">Pending / Outstanding</p>
            <p className="text-2xl font-bold text-yellow-600">${pendingAmount.toFixed(2)}</p>
          </div>
        </div>

        {/* View tabs: full list vs utilities-focused */}
        <div className="flex gap-2 mb-4 border-b border-gray-200 pb-3">
          <button
            type="button"
            onClick={() => setView(VIEW_INVOICES)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              view === VIEW_INVOICES ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
            }`}
          >
            All invoices
          </button>
          <button
            type="button"
            onClick={() => setView(VIEW_UTILITIES)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              view === VIEW_UTILITIES ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
            }`}
          >
            Utilities
          </button>
          <p className="self-center text-xs text-gray-500 ml-2 hidden sm:block">
            Utilities tab lists monthly billing invoices (excludes maintenance damage bills).
          </p>
        </div>

        {/* Filter tabs */}
        <div className="flex flex-wrap gap-2 mb-4">
          {["", "unpaid", "partially_paid", "paid", "overdue"].map((s) => (
            <button key={s || "all"} type="button" onClick={() => setFilter(s)}
              className={`px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
                filter === s ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}>
              {s ? s.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase()) : "All"}
            </button>
          ))}
        </div>

        {loading ? <LoadingSpinner /> : (
          <div className="card overflow-x-auto">
            <table className="w-full min-w-[720px]">
              <thead className="border-b border-gray-200">
                <tr>
                  <th className="table-header">Invoice #</th>
                  <th className="table-header">Tenant</th>
                  <th className="table-header">Billing Month</th>
                  {showUtilityColumns && (
                    <>
                      <th className="table-header text-right">Electricity</th>
                      <th className="table-header text-right">Water</th>
                      <th className="table-header text-right">Waste Mgmt</th>
                    </>
                  )}
                  <th className="table-header text-right">Amount</th>
                  <th className="table-header text-right">Paid</th>
                  <th className="table-header text-right">Remaining</th>
                  <th className="table-header">Status</th>
                  <th className="table-header">Due Date</th>
                  <th className="table-header text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {(showUtilityColumns ? utilityRows : invoices).length === 0 ? (
                  <tr>
                    <td colSpan={showUtilityColumns ? 12 : 9} className="py-12 text-center text-gray-500">
                      {showUtilityColumns ? "No utility-eligible invoices in this filter." : "No invoices found"}
                    </td>
                  </tr>
                ) : (showUtilityColumns ? utilityRows : invoices).map((inv) => (
                  <tr key={inv.id} className={`hover:bg-gray-50 ${inv.status === "overdue" ? "bg-red-50" : ""}`}>
                    <td className="table-cell font-medium">#{inv.id}</td>
                    <td className="table-cell">Tenant #{inv.tenant_id}</td>
                    <td className="table-cell">{inv.billing_month}</td>
                    {showUtilityColumns && (
                      <>
                        <td className="table-cell text-right">${parseFloat(inv.utility_electricity || 0).toFixed(2)}</td>
                        <td className="table-cell text-right">${parseFloat(inv.utility_water || 0).toFixed(2)}</td>
                        <td className="table-cell text-right">${parseFloat(inv.utility_waste || 0).toFixed(2)}</td>
                      </>
                    )}
                    <td className="table-cell text-right">${parseFloat(inv.amount).toFixed(2)}</td>
                    <td className="table-cell text-right text-green-600">${parseFloat(inv.amount_paid || 0).toFixed(2)}</td>
                    <td className="table-cell text-right font-semibold text-red-600">${parseFloat(inv.remaining || 0).toFixed(2)}</td>
                    <td className="table-cell"><StatusBadge status={inv.status} /></td>
                    <td className="table-cell">{inv.due_date}</td>
                    <td className="table-cell text-right">
                      {inv.utilities_editable ? (
                        <button
                          type="button"
                          onClick={() => openUtilityEditor(inv)}
                          className="text-blue-600 hover:underline text-sm font-medium"
                        >
                          Edit utilities
                        </button>
                      ) : (
                        <span className="text-xs text-gray-400" title="Maintenance damage invoices cannot include edited utility charges">
                          —
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {utilityModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
              <h3 className="text-lg font-semibold text-gray-900 mb-1">
                Monthly utilities — Invoice #{utilityModal.id}
              </h3>
              <p className="text-sm text-gray-500 mb-4">
                Adjust charges for this billing period. The invoice total updates from all line items (rent, utilities, discounts).
              </p>
              <div className="space-y-3">
                <div>
                  <label className="form-label" htmlFor="util-electricity">Electricity ($)</label>
                  <input
                    id="util-electricity"
                    type="number"
                    min="0"
                    step="0.01"
                    className="form-input"
                    value={utilityForm.electricity}
                    onChange={(e) => setUtilityForm((f) => ({ ...f, electricity: e.target.value }))}
                  />
                </div>
                <div>
                  <label className="form-label" htmlFor="util-water">Water ($)</label>
                  <input
                    id="util-water"
                    type="number"
                    min="0"
                    step="0.01"
                    className="form-input"
                    value={utilityForm.water}
                    onChange={(e) => setUtilityForm((f) => ({ ...f, water: e.target.value }))}
                  />
                </div>
                <div>
                  <label className="form-label" htmlFor="util-waste">Waste Mgmt ($)</label>
                  <input
                    id="util-waste"
                    type="number"
                    min="0"
                    step="0.01"
                    className="form-input"
                    value={utilityForm.waste}
                    onChange={(e) => setUtilityForm((f) => ({ ...f, waste: e.target.value }))}
                  />
                </div>
              </div>
              {utilityError && <p className="text-sm text-red-600 mt-3">{utilityError}</p>}
              <div className="flex gap-2 mt-6">
                <button type="button" className="btn-secondary flex-1" onClick={() => setUtilityModal(null)} disabled={savingUtilities}>
                  Cancel
                </button>
                <button type="button" className="btn-primary flex-1" onClick={saveUtilities} disabled={savingUtilities}>
                  {savingUtilities ? "Saving..." : "Save"}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  );
}
