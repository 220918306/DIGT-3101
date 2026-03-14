import { useState, useEffect } from "react";
import { getInvoices, getInvoice } from "../../api/invoices";
import { createPayment } from "../../api/payments";
import Navbar from "../../components/Navbar";
import StatusBadge from "../../components/shared/StatusBadge";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

export default function MyInvoices() {
  const [invoices, setInvoices]   = useState([]);
  const [selected, setSelected]   = useState(null);
  const [payAmount, setPayAmount] = useState("");
  const [payMethod, setPayMethod] = useState("online");
  const [loading, setLoading]     = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage]     = useState("");

  const load = () => {
    setLoading(true);
    getInvoices().then((r) => setInvoices(r.data)).finally(() => setLoading(false));
  };
  useEffect(() => { load(); }, []);

  const handleViewDetail = (inv) => {
    getInvoice(inv.id).then((r) => setSelected(r.data));
  };

  const handlePay = async () => {
    if (!payAmount || parseFloat(payAmount) <= 0) return;
    setSubmitting(true);
    try {
      const res = await createPayment({
        invoice_id:     selected.id,
        amount:         parseFloat(payAmount),
        payment_method: payMethod,
      });
      setMessage(`Payment of $${payAmount} recorded! Status: ${res.data.invoice_status}`);
      setSelected(null);
      load();
    } catch (err) {
      setMessage(err.response?.data?.error || "Payment failed.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Navbar />
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-6">My Invoices</h1>

        {message && (
          <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg text-green-700 text-sm flex justify-between">
            {message}
            <button onClick={() => setMessage("")} className="ml-4 text-green-500">✕</button>
          </div>
        )}

        {loading ? <LoadingSpinner /> : (
          <div className="card">
            <table className="w-full">
              <thead className="border-b border-gray-200">
                <tr>
                  <th className="table-header text-left">Invoice</th>
                  <th className="table-header text-left">Billing Month</th>
                  <th className="table-header text-right">Amount</th>
                  <th className="table-header text-right">Paid</th>
                  <th className="table-header text-right">Remaining</th>
                  <th className="table-header text-center">Status</th>
                  <th className="table-header text-left">Due</th>
                  <th className="table-header"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {invoices.length === 0 ? (
                  <tr><td colSpan={8} className="py-12 text-center text-gray-500">No invoices found</td></tr>
                ) : invoices.map((inv) => (
                  <tr key={inv.id} className="hover:bg-gray-50">
                    <td className="table-cell font-medium">#{inv.id}</td>
                    <td className="table-cell">{inv.billing_month}</td>
                    <td className="table-cell text-right">${parseFloat(inv.amount).toFixed(2)}</td>
                    <td className="table-cell text-right text-green-600">${parseFloat(inv.amount_paid || 0).toFixed(2)}</td>
                    <td className="table-cell text-right font-semibold text-red-600">${parseFloat(inv.remaining || 0).toFixed(2)}</td>
                    <td className="table-cell text-center"><StatusBadge status={inv.status} /></td>
                    <td className="table-cell">{inv.due_date}</td>
                    <td className="table-cell">
                      <button onClick={() => handleViewDetail(inv)} className="text-blue-600 hover:underline text-sm">
                        {inv.status !== "paid" ? "Pay Now" : "View"}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Invoice Detail / Pay Modal */}
        {selected && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl p-6 w-full max-w-lg shadow-2xl">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold">Invoice #{selected.id}</h3>
                <StatusBadge status={selected.status} />
              </div>

              {/* Line Items */}
              <div className="bg-gray-50 rounded-lg p-4 mb-4">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-gray-200">
                      <th className="text-left py-1 text-gray-500 font-medium">Item</th>
                      <th className="text-right py-1 text-gray-500 font-medium">Amount</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(selected.line_items || []).map((li) => (
                      <tr key={li.id} className="border-b border-gray-100">
                        <td className="py-1 capitalize">{li.description}</td>
                        <td className={`py-1 text-right font-medium ${parseFloat(li.amount) < 0 ? "text-green-600" : ""}`}>
                          {parseFloat(li.amount) < 0 ? `-$${Math.abs(parseFloat(li.amount)).toFixed(2)}` : `$${parseFloat(li.amount).toFixed(2)}`}
                        </td>
                      </tr>
                    ))}
                    <tr className="font-semibold text-gray-900">
                      <td className="py-2">Total</td>
                      <td className="py-2 text-right">${parseFloat(selected.amount).toFixed(2)}</td>
                    </tr>
                  </tbody>
                </table>
                <div className="flex justify-between text-sm mt-2 pt-2 border-t border-gray-200">
                  <span className="text-gray-500">Amount Paid</span>
                  <span className="text-green-600 font-medium">${parseFloat(selected.amount_paid || 0).toFixed(2)}</span>
                </div>
                <div className="flex justify-between text-sm mt-1 font-bold text-red-600">
                  <span>Remaining Balance</span>
                  <span>${parseFloat(selected.remaining || 0).toFixed(2)}</span>
                </div>
              </div>

              {selected.status !== "paid" && (
                <div className="space-y-3">
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="form-label">Payment Amount</label>
                      <input type="number" className="form-input" placeholder={selected.remaining}
                        value={payAmount} onChange={(e) => setPayAmount(e.target.value)} />
                    </div>
                    <div>
                      <label className="form-label">Payment Method</label>
                      <select className="form-select" value={payMethod} onChange={(e) => setPayMethod(e.target.value)}>
                        <option value="online">Online</option>
                        <option value="wire">Wire Transfer</option>
                        <option value="check">Check</option>
                        <option value="manual">Manual</option>
                      </select>
                    </div>
                  </div>
                </div>
              )}

              <div className="flex gap-2 mt-4">
                <button className="btn-secondary flex-1" onClick={() => setSelected(null)}>Close</button>
                {selected.status !== "paid" && (
                  <button className="btn-success flex-1" onClick={handlePay} disabled={submitting}>
                    {submitting ? "Processing..." : "Confirm Payment"}
                  </button>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  );
}
