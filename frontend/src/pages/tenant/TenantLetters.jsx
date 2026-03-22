import { useEffect, useState } from "react";
import { getLetters, signLetter } from "../../api/letters";
import Navbar from "../../components/Navbar";
import StatusBadge from "../../components/shared/StatusBadge";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

export default function TenantLetters() {
  const [letters, setLetters] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState("");

  const load = () => {
    setLoading(true);
    getLetters()
      .then((r) => setLetters(r.data || []))
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const handleSign = async () => {
    if (!selected) return;
    setSubmitting(true);
    try {
      await signLetter(selected.id);
      setMessage("Agreement signed successfully.");
      setSelected(null);
      load();
    } catch (err) {
      setMessage(err.response?.data?.error || "Could not sign agreement.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Navbar />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-6">Letters</h1>

        {message && (
          <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg text-green-700 text-sm flex justify-between">
            {message}
            <button onClick={() => setMessage("")} className="ml-4 text-green-500 hover:text-green-700">✕</button>
          </div>
        )}

        {loading ? <LoadingSpinner /> : (
          <div className="card">
            <table className="w-full">
              <thead className="border-b border-gray-200">
                <tr>
                  <th className="table-header">Subject</th>
                  <th className="table-header">Type</th>
                  <th className="table-header">Lease</th>
                  <th className="table-header">Sent At</th>
                  <th className="table-header">Status</th>
                  <th className="table-header"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {letters.length === 0 ? (
                  <tr><td colSpan={6} className="py-12 text-center text-gray-500">No letters found</td></tr>
                ) : letters.map((l) => (
                  <tr key={l.id} className="hover:bg-gray-50">
                    <td className="table-cell">{l.subject}</td>
                    <td className="table-cell capitalize">{l.letter_type?.replace(/_/g, " ")}</td>
                    <td className="table-cell">#{l.lease_id}</td>
                    <td className="table-cell">{l.sent_at ? new Date(l.sent_at).toLocaleString() : "—"}</td>
                    <td className="table-cell"><StatusBadge status={l.status} /></td>
                    <td className="table-cell">
                      <button onClick={() => setSelected(l)} className="text-blue-600 hover:underline text-sm">
                        View
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {selected && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl p-6 w-full max-w-2xl shadow-2xl">
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-lg font-semibold">{selected.subject}</h3>
                <StatusBadge status={selected.status} />
              </div>
              <div className="bg-gray-50 rounded-lg p-4 max-h-80 overflow-y-auto whitespace-pre-line text-sm text-gray-700">
                {selected.body}
              </div>
              <div className="flex gap-2 mt-5">
                <button className="btn-secondary flex-1" onClick={() => setSelected(null)}>Close</button>
                {selected.status !== "signed" && (
                  <button className="btn-success flex-1" onClick={handleSign} disabled={submitting}>
                    {submitting ? "Signing..." : "Agree & Sign"}
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
