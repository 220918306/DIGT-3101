import { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

const REQUIRED_FIELDS = [
  { key: "name", label: "Full name" },
  { key: "email", label: "Email" },
  { key: "password", label: "Password" },
  { key: "company_name", label: "Company name" },
];

export default function Register() {
  const { register } = useAuth();
  const navigate     = useNavigate();
  const [form, setForm]     = useState({ name: "", email: "", password: "", phone: "", company_name: "" });
  const [errors, setErrors] = useState([]);
  const [toast, setToast]   = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!toast) return undefined;
    const t = setTimeout(() => setToast(null), 6000);
    return () => clearTimeout(t);
  }, [toast]);

  const missingRequiredLabels = () =>
    REQUIRED_FIELDS.filter(({ key }) => {
      const v = form[key];
      return key === "password" ? !v : !String(v || "").trim();
    }).map(({ label }) => label);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrors([]);
    const missing = missingRequiredLabels();
    if (missing.length > 0) {
      setToast(`Please fill in: ${missing.join(", ")}`);
      return;
    }
    setLoading(true);
    try {
      await register(form);
      navigate("/tenant");
    } catch (err) {
      const msg = err.response?.data?.errors || [err.response?.data?.error || "Registration failed."];
      setErrors(Array.isArray(msg) ? msg : [msg]);
    } finally {
      setLoading(false);
    }
  };

  const field = (key, label, type = "text", placeholder = "") => (
    <div>
      <label className="form-label">{label}</label>
      <input
        type={type}
        className="form-input"
        placeholder={placeholder}
        value={form[key]}
        onChange={(e) => setForm({ ...form, [key]: e.target.value })}
        autoComplete={key === "password" ? "new-password" : key === "email" ? "email" : undefined}
      />
    </div>
  );

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-900 via-blue-800 to-indigo-900 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-white rounded-2xl shadow-lg mb-4">
            <span className="text-blue-700 font-black text-2xl">R</span>
          </div>
          <h1 className="text-3xl font-bold text-white">Create Account</h1>
          <p className="text-blue-200 mt-1">Register as a new tenant</p>
        </div>

        <div className="bg-white rounded-2xl shadow-2xl p-8">
          {errors.length > 0 && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
              {errors.map((e, i) => (
                <p key={i} className="text-red-700 text-sm">{e}</p>
              ))}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4" noValidate>
            {field("name",         "Full name",      "text",     "Alice Smith")}
            {field("email",        "Email",          "email",    "alice@example.com")}
            {field("password",     "Password",       "password", "At least 6 characters")}
            {field("phone",        "Phone (optional)", "tel",      "416-555-0100")}
            {field("company_name", "Company name",   "text",     "Alice's Boutique")}

            <button type="submit" className="btn-primary w-full py-2.5" disabled={loading}>
              {loading ? "Creating account..." : "Create Account"}
            </button>
          </form>

          <p className="mt-4 text-center text-sm text-gray-600">
            Already have an account?{" "}
            <Link to="/login" className="text-blue-600 font-medium hover:underline">Sign in</Link>
          </p>
        </div>
      </div>

      {toast && (
        <div
          role="alert"
          className="fixed bottom-6 left-1/2 z-[100] w-[calc(100%-2rem)] max-w-md -translate-x-1/2 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-center text-sm text-amber-950 shadow-lg"
        >
          <span>{toast}</span>
          <button
            type="button"
            onClick={() => setToast(null)}
            className="ml-3 text-amber-800/70 hover:text-amber-950"
            aria-label="Dismiss"
          >
            ✕
          </button>
        </div>
      )}
    </div>
  );
}
