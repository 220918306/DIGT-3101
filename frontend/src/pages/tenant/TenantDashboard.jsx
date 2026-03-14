import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { getInvoices } from "../../api/invoices";
import { getLeases } from "../../api/leases";
import { getTickets } from "../../api/maintenance";
import Navbar from "../../components/Navbar";
import StatusBadge from "../../components/shared/StatusBadge";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

function StatCard({ label, value, color, icon }) {
  return (
    <div className={`card border-l-4 ${color}`}>
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-500">{label}</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
        </div>
        <div className="text-3xl">{icon}</div>
      </div>
    </div>
  );
}

export default function TenantDashboard() {
  const { user } = useAuth();
  const [invoices, setInvoices] = useState([]);
  const [leases, setLeases]     = useState([]);
  const [tickets, setTickets]   = useState([]);
  const [loading, setLoading]   = useState(true);

  useEffect(() => {
    Promise.all([getInvoices(), getLeases(), getTickets()])
      .then(([inv, lea, tix]) => {
        setInvoices(inv.data);
        setLeases(lea.data);
        setTickets(tix.data);
      })
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <><Navbar /><LoadingSpinner /></>;

  const unpaidTotal = invoices
    .filter((i) => i.status !== "paid")
    .reduce((s, i) => s + parseFloat(i.remaining || 0), 0);
  const openTickets = tickets.filter((t) => ["open", "in_progress"].includes(t.status)).length;

  return (
    <>
      <Navbar />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-gray-900">Welcome back, {user?.name} 👋</h1>
          <p className="text-gray-500 mt-1">Here&apos;s your tenant overview</p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <StatCard label="Active Leases"     value={leases.filter((l) => l.status === "active").length} color="border-green-500" icon="🏪" />
          <StatCard label="Open Invoices"     value={invoices.filter((i) => i.status !== "paid").length}  color="border-yellow-500" icon="📄" />
          <StatCard label="Amount Due"        value={`$${unpaidTotal.toFixed(2)}`}                         color="border-red-500" icon="💰" />
          <StatCard label="Open Tickets"      value={openTickets}                                           color="border-blue-500" icon="🔧" />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Recent Invoices */}
          <div className="card">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900">Recent Invoices</h2>
              <Link to="/tenant/invoices" className="text-sm text-blue-600 hover:underline">View all</Link>
            </div>
            {invoices.length === 0 ? (
              <p className="text-gray-500 text-sm py-4 text-center">No invoices yet</p>
            ) : (
              <div className="space-y-3">
                {invoices.slice(0, 4).map((inv) => (
                  <div key={inv.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                    <div>
                      <p className="text-sm font-medium text-gray-900">Invoice #{inv.id}</p>
                      <p className="text-xs text-gray-500">Due {inv.due_date}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-semibold text-gray-900">${parseFloat(inv.amount).toFixed(2)}</p>
                      <StatusBadge status={inv.status} />
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Quick Actions */}
          <div className="card">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h2>
            <div className="grid grid-cols-2 gap-3">
              {[
                { to: "/tenant/units",       icon: "🔍", label: "Browse Units",      desc: "Find available spaces" },
                { to: "/tenant/invoices",     icon: "💳", label: "Pay Invoice",        desc: "View and pay bills"   },
                { to: "/tenant/maintenance",  icon: "🔧", label: "Report Issue",       desc: "Submit maintenance"   },
                { to: "/tenant/units",        icon: "📅", label: "Book Viewing",        desc: "Schedule a visit"     },
              ].map((action) => (
                <Link key={action.to + action.label} to={action.to}
                  className="flex flex-col items-center p-4 bg-blue-50 hover:bg-blue-100 rounded-xl transition-colors text-center group">
                  <span className="text-2xl mb-2">{action.icon}</span>
                  <span className="text-sm font-semibold text-blue-900 group-hover:text-blue-700">{action.label}</span>
                  <span className="text-xs text-blue-600 mt-0.5">{action.desc}</span>
                </Link>
              ))}
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
