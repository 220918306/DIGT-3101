import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { getOccupancyReport, getRevenueReport, getMaintenanceReport } from "../../api/reports";
import Navbar from "../../components/Navbar";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

function MetricCard({ label, value, sub, color, icon }) {
  return (
    <div className={`card border-l-4 ${color}`}>
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-500">{label}</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
          {sub && <p className="text-xs text-gray-400 mt-0.5">{sub}</p>}
        </div>
        <div className="text-3xl">{icon}</div>
      </div>
    </div>
  );
}

export default function AdminDashboard() {
  const [occupancy, setOccupancy]     = useState(null);
  const [revenue, setRevenue]         = useState(null);
  const [maintenance, setMaintenance] = useState(null);
  const [loading, setLoading]         = useState(true);

  useEffect(() => {
    Promise.all([getOccupancyReport(), getRevenueReport(), getMaintenanceReport()])
      .then(([o, r, m]) => {
        setOccupancy(o.data);
        setRevenue(r.data);
        setMaintenance(m.data);
      })
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <><Navbar /><LoadingSpinner /></>;

  return (
    <>
      <Navbar />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-gray-900">Admin Dashboard</h1>
          <p className="text-gray-500 mt-1">System overview</p>
        </div>

        <h2 className="text-lg font-semibold text-gray-700 mb-3">Occupancy</h2>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <MetricCard label="Total Units"    value={occupancy?.total_units}    color="border-gray-400" icon="🏬" />
          <MetricCard label="Occupied"       value={occupancy?.occupied_units} color="border-blue-500" icon="🔒" />
          <MetricCard label="Available"      value={occupancy?.available_units} color="border-green-500" icon="✅" />
          <MetricCard label="Occupancy Rate" value={`${occupancy?.occupancy_rate}%`} color="border-purple-500" icon="📊" />
        </div>

        <h2 className="text-lg font-semibold text-gray-700 mb-3">Revenue (Last 30 Days)</h2>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <MetricCard label="Collected"      value={`$${parseFloat(revenue?.total_revenue || 0).toLocaleString()}`} color="border-green-500" icon="💵" />
          <MetricCard label="Invoices Paid"  value={revenue?.invoice_count} color="border-green-400" icon="📄" />
          <MetricCard label="Pending"        value={`$${parseFloat(revenue?.pending_revenue || 0).toLocaleString()}`} color="border-yellow-500" icon="⏳" />
          <MetricCard label="Overdue"        value={`$${parseFloat(revenue?.overdue_amount || 0).toLocaleString()}`} color="border-red-500" icon="⚠️" />
        </div>

        <h2 className="text-lg font-semibold text-gray-700 mb-3">Maintenance</h2>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <MetricCard label="Open"        value={maintenance?.open}        color="border-yellow-500" icon="📋" />
          <MetricCard label="In Progress" value={maintenance?.in_progress} color="border-blue-500"   icon="🔧" />
          <MetricCard label="Emergencies" value={maintenance?.emergency}   color="border-red-600"    icon="🚨" />
          <MetricCard label="Completed"   value={maintenance?.completed}   color="border-green-500"  icon="✅" />
        </div>

        {/* Tier Breakdown */}
        {occupancy?.breakdown_by_tier && (
          <>
            <h2 className="text-lg font-semibold text-gray-700 mb-3">Units by Tier</h2>
            <div className="grid grid-cols-3 gap-4 mb-8">
              {Object.entries(occupancy.breakdown_by_tier).map(([tier, count]) => (
                <div key={tier} className="card text-center">
                  <p className="text-2xl font-bold text-gray-900">{count}</p>
                  <p className="text-sm text-gray-500 capitalize mt-1">{tier} units</p>
                </div>
              ))}
            </div>
          </>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Link to="/admin/reports" className="card hover:shadow-md transition-shadow text-center py-8 bg-purple-50 border-purple-200 border">
            <div className="text-4xl mb-3">📊</div>
            <h3 className="font-semibold text-purple-900 text-lg">Detailed Reports</h3>
            <p className="text-sm text-purple-600 mt-1">Revenue, occupancy, maintenance analytics</p>
          </Link>
        </div>
      </div>
    </>
  );
}
