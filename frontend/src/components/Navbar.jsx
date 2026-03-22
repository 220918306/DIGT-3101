import { Link, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

const ROLE_LINKS = {
  tenant: [
    { to: "/tenant",              label: "Dashboard"    },
    { to: "/tenant/units",        label: "Find Units"   },
    { to: "/tenant/leases",       label: "My Leases"    },
    { to: "/tenant/letters",      label: "Letters"      },
    { to: "/tenant/maintenance",  label: "Maintenance"  },
  ],
  clerk: [
    { to: "/clerk",               label: "Dashboard"    },
    { to: "/clerk/tenants",       label: "Tenants"      },
    { to: "/clerk/units",         label: "Units"        },
    { to: "/clerk/invoices",      label: "Invoices"     },
    { to: "/clerk/maintenance",   label: "Maintenance"  },
  ],
  admin: [
    { to: "/admin",               label: "Dashboard"    },
    { to: "/clerk/tenants",       label: "Tenants"      },
    { to: "/clerk/units",         label: "Units"        },
    { to: "/clerk/invoices",      label: "Invoices"     },
    { to: "/clerk/maintenance",   label: "Maintenance"  },
    { to: "/admin/reports",       label: "Reports"      },
  ],
};

export default function Navbar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  const links = ROLE_LINKS[user?.role] || [];
  const roleColors = { admin: "from-purple-700 to-purple-900", clerk: "from-teal-700 to-teal-900", tenant: "from-blue-700 to-blue-900" };
  const gradient  = roleColors[user?.role] || "from-blue-700 to-blue-900";

  return (
    <nav className={`bg-gradient-to-r ${gradient} shadow-lg`}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center gap-8">
            <Link to="/" className="flex items-center gap-2">
              <div className="w-8 h-8 bg-white rounded-lg flex items-center justify-center">
                <span className="text-blue-700 font-black text-sm">R</span>
              </div>
              <span className="text-white font-bold text-lg tracking-tight">REMS</span>
            </Link>
            <div className="hidden md:flex items-center gap-1">
              {links.map((link) => (
                <Link
                  key={link.to}
                  to={link.to}
                  className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                    location.pathname === link.to
                      ? "bg-white/20 text-white"
                      : "text-white/80 hover:text-white hover:bg-white/10"
                  }`}
                >
                  {link.label}
                </Link>
              ))}
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="hidden sm:block text-right">
              <p className="text-white text-sm font-medium">{user?.name}</p>
              <p className="text-white/60 text-xs capitalize">{user?.role}</p>
            </div>
            <button
              onClick={handleLogout}
              className="px-3 py-1.5 bg-white/10 hover:bg-white/20 text-white text-sm rounded-lg transition-colors border border-white/20"
            >
              Sign Out
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
}
