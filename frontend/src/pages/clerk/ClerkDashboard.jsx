import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { getApplications } from "../../api/applications";
import { getTickets } from "../../api/maintenance";
import { getInvoices } from "../../api/invoices";
import Navbar from "../../components/Navbar";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

function StatCard({ label, value, color, icon, to }) {
  const content = (
    <div className={`card border-l-4 ${color} hover:shadow-md transition-shadow`}>
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-500">{label}</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
        </div>
        <div className="text-3xl">{icon}</div>
      </div>
    </div>
  );
  return to ? <Link to={to}>{content}</Link> : content;
}

export default function ClerkDashboard() {
  const [stats, setStats] = useState({ pending: 0, openTickets: 0, overdueInvoices: 0, emergencies: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      getApplications({ status: "pending" }),
      getTickets(),
      getInvoices({ status: "overdue" }),
    ]).then(([apps, tickets, invoices]) => {
      setStats({
        pending:        apps.data.length,
        openTickets:    tickets.data.filter((t) => t.status === "open").length,
        overdueInvoices: invoices.data.length,
        emergencies:    tickets.data.filter((t) => t.priority === "emergency" && t.status !== "completed").length,
      });
    }).finally(() => setLoading(false));
  }, []);

  if (loading) return <><Navbar /><LoadingSpinner /></>;

  return (
    <>
      <Navbar />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-gray-900">Clerk Dashboard</h1>
          <p className="text-gray-500 mt-1">Here&apos;s what needs your attention</p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <StatCard label="Pending Applications" value={stats.pending}         color="border-yellow-500" icon="📋" to="/clerk/applications" />
          <StatCard label="Open Tickets"          value={stats.openTickets}    color="border-blue-500"   icon="🔧" to="/clerk/maintenance" />
          <StatCard label="Overdue Invoices"      value={stats.overdueInvoices} color="border-red-500"   icon="⏰" to="/clerk/invoices" />
          <StatCard label="Active Emergencies"    value={stats.emergencies}    color="border-red-700"    icon="🚨" to="/clerk/maintenance" />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {[
            { to: "/clerk/tenants",      icon: "📋", label: "Manage Tenants",      desc: "Applications and active leases", color: "bg-yellow-50 border-yellow-200" },
            { to: "/clerk/units",        icon: "🏬", label: "Manage Units",         desc: "Update unit details and availability", color: "bg-purple-50 border-purple-200" },
            { to: "/clerk/maintenance",  icon: "🔧", label: "Manage Tickets",       desc: "Update status and assign technicians", color: "bg-blue-50 border-blue-200" },
            { to: "/clerk/invoices",     icon: "📄", label: "Invoice Management",   desc: "Generate and track invoices", color: "bg-green-50 border-green-200" },
          ].map((item) => (
            <Link key={item.to} to={item.to}
              className={`${item.color} border rounded-xl p-5 hover:shadow-md transition-shadow`}>
              <div className="text-3xl mb-3">{item.icon}</div>
              <h3 className="font-semibold text-gray-900">{item.label}</h3>
              <p className="text-sm text-gray-500 mt-1">{item.desc}</p>
            </Link>
          ))}
        </div>
      </div>
    </>
  );
}
