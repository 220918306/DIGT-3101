import { useState } from "react";
import { getOccupancyReport, getRevenueReport, getMaintenanceReport } from "../../api/reports";
import Navbar from "../../components/Navbar";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

export default function Reports() {
  const [tab, setTab]             = useState("occupancy");
  const [data, setData]           = useState(null);
  const [loading, setLoading]     = useState(false);
  const [dateRange, setDateRange] = useState({ start_date: "", end_date: "" });

  const fetchReport = async () => {
    setLoading(true);
    setData(null);
    try {
      let res;
      if (tab === "occupancy")   res = await getOccupancyReport();
      else if (tab === "revenue") res = await getRevenueReport(dateRange);
      else                        res = await getMaintenanceReport();
      setData(res.data);
    } finally {
      setLoading(false);
    }
  };

  const tabs = [
    { id: "occupancy",   label: "Occupancy",   icon: "🏬" },
    { id: "revenue",     label: "Revenue",     icon: "💵" },
    { id: "maintenance", label: "Maintenance", icon: "🔧" },
  ];

  return (
    <>
      <Navbar />
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-6">System Reports</h1>

        {/* Tab selector */}
        <div className="flex gap-2 mb-6">
          {tabs.map((t) => (
            <button key={t.id} onClick={() => { setTab(t.id); setData(null); }}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                tab === t.id ? "bg-purple-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
              }`}>
              {t.icon} {t.label}
            </button>
          ))}
        </div>

        {/* Revenue date pickers */}
        {tab === "revenue" && (
          <div className="card mb-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="form-label">Start Date</label>
                <input type="date" className="form-input" value={dateRange.start_date}
                  onChange={(e) => setDateRange({ ...dateRange, start_date: e.target.value })} />
              </div>
              <div>
                <label className="form-label">End Date</label>
                <input type="date" className="form-input" value={dateRange.end_date}
                  onChange={(e) => setDateRange({ ...dateRange, end_date: e.target.value })} />
              </div>
            </div>
          </div>
        )}

        <button onClick={fetchReport} disabled={loading} className="btn-primary mb-6">
          {loading ? "Loading..." : `Generate ${tab.charAt(0).toUpperCase() + tab.slice(1)} Report`}
        </button>

        {loading && <LoadingSpinner />}

        {data && tab === "occupancy" && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
              {[
                ["Total Units",    data.total_units,     "border-gray-400"],
                ["Occupied",       data.occupied_units,  "border-blue-500"],
                ["Available",      data.available_units, "border-green-500"],
                ["Occupancy Rate", `${data.occupancy_rate}%`, "border-purple-500"],
              ].map(([label, value, color]) => (
                <div key={label} className={`card border-l-4 ${color}`}>
                  <p className="text-sm text-gray-500">{label}</p>
                  <p className="text-2xl font-bold text-gray-900">{value}</p>
                </div>
              ))}
            </div>
            {data.breakdown_by_tier && (
              <div className="card">
                <h3 className="font-semibold text-gray-900 mb-3">Breakdown by Tier</h3>
                <div className="grid grid-cols-3 gap-4 text-center">
                  {Object.entries(data.breakdown_by_tier).map(([tier, count]) => (
                    <div key={tier} className="bg-gray-50 rounded-lg p-3">
                      <p className="text-xl font-bold text-gray-900">{count}</p>
                      <p className="text-sm text-gray-500 capitalize">{tier}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {data && tab === "revenue" && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              {[
                ["Total Collected",  `$${parseFloat(data.total_revenue || 0).toLocaleString()}`,  "border-green-500"],
                ["Invoices Paid",    data.invoice_count,                                           "border-green-400"],
                ["Pending Revenue",  `$${parseFloat(data.pending_revenue || 0).toLocaleString()}`, "border-yellow-500"],
                ["Overdue Amount",   `$${parseFloat(data.overdue_amount || 0).toLocaleString()}`,  "border-red-500"],
              ].map(([label, value, color]) => (
                <div key={label} className={`card border-l-4 ${color}`}>
                  <p className="text-sm text-gray-500">{label}</p>
                  <p className="text-2xl font-bold text-gray-900">{value}</p>
                </div>
              ))}
            </div>
            <div className="card text-sm text-gray-500">
              Report period: <strong>{data.period?.start}</strong> → <strong>{data.period?.end}</strong>
            </div>
          </div>
        )}

        {data && tab === "maintenance" && (
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {[
              ["Open Tickets",     data.open,            "border-yellow-500", "📋"],
              ["In Progress",      data.in_progress,     "border-blue-500",   "🔧"],
              ["Emergencies",      data.emergency,       "border-red-600",    "🚨"],
              ["Completed",        data.completed,       "border-green-500",  "✅"],
              ["Urgent Active",    data.urgent,          "border-orange-500", "⚠️"],
              ["Routine Active",   data.routine,         "border-gray-400",   "🛠️"],
              ["Tenant-Caused",    data.tenant_caused,   "border-red-400",    "💸"],
              ["Avg Resolution",   `${data.avg_resolution_hours}h`, "border-purple-500", "⏱️"],
            ].map(([label, value, color, icon]) => (
              <div key={label} className={`card border-l-4 ${color}`}>
                <div className="flex justify-between items-center">
                  <div>
                    <p className="text-xs text-gray-500">{label}</p>
                    <p className="text-xl font-bold text-gray-900">{value}</p>
                  </div>
                  <span className="text-2xl">{icon}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  );
}
