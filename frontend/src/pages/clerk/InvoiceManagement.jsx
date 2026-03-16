import { useState, useEffect } from "react";
import { getInvoices, generateInvoices } from "../../api/invoices";
import Navbar from "../../components/Navbar";
import StatusBadge from "../../components/shared/StatusBadge";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

export default function InvoiceManagement() {
  const [invoices, setInvoices]   = useState([]);
  const [filter, setFilter]       = useState("");
  const [loading, setLoading]     = useState(true);
  const [generating, setGenerating] = useState(false);
  const [message, setMessage]     = useState("");

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

  const totalRevenue = invoices.filter((i) => i.status === "paid").reduce((s, i) => s + parseFloat(i.amount_paid || 0), 0);
  const pendingAmount = invoices.filter((i) => i.status !== "paid").reduce((s, i) => s + parseFloat(i.remaining || 0), 0);

  return (
    <>
      <Navbar />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Invoice Management</h1>
          <button onClick={handleGenerate} disabled={generating} className="btn-primary">
            {generating ? "Generating..." : "⚡ Generate Monthly Invoices"}
          </button>
        </div>

        {message && (
          <div className="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-lg text-blue-700 text-sm flex justify-between">
            {message}<button onClick={() => setMessage("")} className="ml-4">✕</button>
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

        {/* Filter tabs */}
        <div className="flex gap-2 mb-4">
          {["", "unpaid", "partially_paid", "paid", "overdue"].map((s) => (
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
                  <th className="table-header">Invoice #</th>
                  <th className="table-header">Tenant</th>
                  <th className="table-header">Billing Month</th>
                  <th className="table-header text-right">Amount</th>
                  <th className="table-header text-right">Paid</th>
                  <th className="table-header text-right">Remaining</th>
                  <th className="table-header">Status</th>
                  <th className="table-header">Due Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {invoices.length === 0 ? (
                  <tr><td colSpan={8} className="py-12 text-center text-gray-500">No invoices found</td></tr>
                ) : invoices.map((inv) => (
                  <tr key={inv.id} className={`hover:bg-gray-50 ${inv.status === "overdue" ? "bg-red-50" : ""}`}>
                    <td className="table-cell font-medium">#{inv.id}</td>
                    <td className="table-cell">Tenant #{inv.tenant_id}</td>
                    <td className="table-cell">{inv.billing_month}</td>
                    <td className="table-cell text-right">${parseFloat(inv.amount).toFixed(2)}</td>
                    <td className="table-cell text-right text-green-600">${parseFloat(inv.amount_paid || 0).toFixed(2)}</td>
                    <td className="table-cell text-right font-semibold text-red-600">${parseFloat(inv.remaining || 0).toFixed(2)}</td>
                    <td className="table-cell"><StatusBadge status={inv.status} /></td>
                    <td className="table-cell">{inv.due_date}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}
