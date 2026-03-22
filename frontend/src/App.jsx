import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";

import Login    from "./pages/Login";
import Register from "./pages/Register";

import TenantDashboard    from "./pages/tenant/TenantDashboard";
import UnitSearch         from "./pages/tenant/UnitSearch";
import MyInvoices         from "./pages/tenant/MyInvoices";
import TenantLetters      from "./pages/tenant/TenantLetters";
import MaintenanceRequest from "./pages/tenant/MaintenanceRequest";

import ClerkDashboard    from "./pages/clerk/ClerkDashboard";
import ApplicationsList  from "./pages/clerk/ApplicationsList";
import InvoiceManagement from "./pages/clerk/InvoiceManagement";
import MaintenanceQueue  from "./pages/clerk/MaintenanceQueue";
import UnitsManagement   from "./pages/clerk/UnitsManagement";

import AdminDashboard from "./pages/admin/AdminDashboard";
import Reports        from "./pages/admin/Reports";

function ProtectedRoute({ children, roles }) {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" replace />;
  if (roles && !roles.includes(user.role)) return <Navigate to="/login" replace />;
  return children;
}

function RoleRedirect() {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" replace />;
  const routes = { admin: "/admin", clerk: "/clerk", tenant: "/tenant" };
  return <Navigate to={routes[user.role] || "/login"} replace />;
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          {/* Public */}
          <Route path="/login"    element={<Login />} />
          <Route path="/register" element={<Register />} />

          {/* Tenant */}
          <Route path="/tenant" element={<ProtectedRoute roles={["tenant"]}><TenantDashboard /></ProtectedRoute>} />
          <Route path="/tenant/units"       element={<ProtectedRoute roles={["tenant"]}><UnitSearch /></ProtectedRoute>} />
          <Route path="/tenant/leases"      element={<ProtectedRoute roles={["tenant"]}><MyInvoices /></ProtectedRoute>} />
          <Route path="/tenant/invoices"    element={<ProtectedRoute roles={["tenant"]}><MyInvoices /></ProtectedRoute>} />
          <Route path="/tenant/letters"     element={<ProtectedRoute roles={["tenant"]}><TenantLetters /></ProtectedRoute>} />
          <Route path="/tenant/maintenance" element={<ProtectedRoute roles={["tenant"]}><MaintenanceRequest /></ProtectedRoute>} />

          {/* Clerk */}
          <Route path="/clerk" element={<ProtectedRoute roles={["clerk", "admin"]}><ClerkDashboard /></ProtectedRoute>} />
          <Route path="/clerk/applications" element={<ProtectedRoute roles={["clerk", "admin"]}><ApplicationsList /></ProtectedRoute>} />
          <Route path="/clerk/tenants"      element={<ProtectedRoute roles={["clerk", "admin"]}><ApplicationsList /></ProtectedRoute>} />
          <Route path="/clerk/units"        element={<ProtectedRoute roles={["clerk", "admin"]}><UnitsManagement /></ProtectedRoute>} />
          <Route path="/clerk/invoices"     element={<ProtectedRoute roles={["clerk", "admin"]}><InvoiceManagement /></ProtectedRoute>} />
          <Route path="/clerk/maintenance"  element={<ProtectedRoute roles={["clerk", "admin"]}><MaintenanceQueue /></ProtectedRoute>} />

          {/* Admin */}
          <Route path="/admin"         element={<ProtectedRoute roles={["admin"]}><AdminDashboard /></ProtectedRoute>} />
          <Route path="/admin/reports" element={<ProtectedRoute roles={["admin", "clerk"]}><Reports /></ProtectedRoute>} />

          {/* Default */}
          <Route path="/"  element={<RoleRedirect />} />
          <Route path="*"  element={<Navigate to="/login" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
