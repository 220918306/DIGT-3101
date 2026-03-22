import { useEffect, useState } from "react";
import { getUnits, createUnit, updateUnit } from "../../api/units";
import Navbar from "../../components/Navbar";
import StatusBadge from "../../components/shared/StatusBadge";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

export default function UnitsManagement() {
  const [units, setUnits] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({});
  const [createForm, setCreateForm] = useState({
    property_id: "",
    unit_number: "",
    size: "",
    rental_rate: "",
    tier: "standard",
    purpose: "retail",
    status: "available",
  });
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState("");

  const load = () => {
    setLoading(true);
    getUnits()
      .then((r) => {
        const list = r.data || [];
        setUnits(list);
        if (!createForm.property_id && list.length > 0) {
          const firstPropertyId = list[0].property?.id;
          if (firstPropertyId) {
            setCreateForm((prev) => ({ ...prev, property_id: String(firstPropertyId) }));
          }
        }
      })
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const beginEdit = (unit) => {
    setEditingId(unit.id);
    setForm({
      unit_number: unit.unit_number || "",
      size: unit.size ?? "",
      rental_rate: unit.rental_rate ?? "",
      tier: unit.tier || "standard",
      purpose: unit.purpose || "retail",
      status: unit.status || "available",
      available: Boolean(unit.available),
    });
  };

  const cancelEdit = () => {
    setEditingId(null);
    setForm({});
  };

  const saveEdit = async () => {
    setSubmitting(true);
    try {
      await updateUnit(editingId, form);
      setMessage(`Unit #${editingId} updated.`);
      cancelEdit();
      load();
    } catch (err) {
      setMessage(err.response?.data?.errors?.join(", ") || "Update failed.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    const propertyId = Number(createForm.property_id);
    if (!propertyId || Number.isNaN(propertyId) || propertyId <= 0) {
      setMessage("Please select a valid property before creating a unit.");
      return;
    }

    setSubmitting(true);
    try {
      await createUnit({
        ...createForm,
        property_id: propertyId,
      });
      setMessage("New unit created.");
      setCreateForm((prev) => ({
        ...prev,
        unit_number: "",
        size: "",
        rental_rate: "",
      }));
      load();
    } catch (err) {
      setMessage(err.response?.data?.errors?.join(", ") || "Create failed.");
    } finally {
      setSubmitting(false);
    }
  };

  const properties = Array.from(
    new Map(
      units
        .filter((u) => u.property?.id)
        .map((u) => [u.property.id, { id: u.property.id, name: u.property.name }])
    ).values()
  );

  return (
    <>
      <Navbar />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-6">Units Management</h1>

        {message && (
          <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg text-green-700 text-sm flex justify-between">
            {message}
            <button onClick={() => setMessage("")} className="ml-4 text-green-500 hover:text-green-700">✕</button>
          </div>
        )}

        <form onSubmit={handleCreate} className="card mb-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Create New Unit</h2>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
            <div>
              <label className="form-label">Property</label>
              <select
                className="form-select"
                value={createForm.property_id}
                onChange={(e) => setCreateForm({ ...createForm, property_id: e.target.value })}
                required
              >
                <option value="">Select property</option>
                {properties.map((p) => (
                  <option key={p.id} value={p.id}>{p.name}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="form-label">Unit Number</label>
              <input
                className="form-input"
                value={createForm.unit_number}
                onChange={(e) => setCreateForm({ ...createForm, unit_number: e.target.value })}
                required
              />
            </div>
            <div>
              <label className="form-label">Size (sq ft)</label>
              <input
                type="number"
                className="form-input"
                value={createForm.size}
                onChange={(e) => setCreateForm({ ...createForm, size: e.target.value })}
                required
              />
            </div>
            <div>
              <label className="form-label">Rate ($/mo)</label>
              <input
                type="number"
                className="form-input"
                value={createForm.rental_rate}
                onChange={(e) => setCreateForm({ ...createForm, rental_rate: e.target.value })}
                required
              />
            </div>
            <div>
              <label className="form-label">Tier</label>
              <select className="form-select" value={createForm.tier}
                onChange={(e) => setCreateForm({ ...createForm, tier: e.target.value })}>
                <option value="standard">Standard</option>
                <option value="premium">Premium</option>
                <option value="anchor">Anchor</option>
              </select>
            </div>
            <div>
              <label className="form-label">Purpose</label>
              <select className="form-select" value={createForm.purpose}
                onChange={(e) => setCreateForm({ ...createForm, purpose: e.target.value })}>
                <option value="retail">Retail</option>
                <option value="food">Food</option>
                <option value="services">Services</option>
              </select>
            </div>
            <div>
              <label className="form-label">Status</label>
              <select className="form-select" value={createForm.status}
                onChange={(e) => setCreateForm({ ...createForm, status: e.target.value })}>
                <option value="available">Available</option>
                <option value="occupied">Occupied</option>
                <option value="under_maintenance">Under Maintenance</option>
              </select>
            </div>
          </div>
          <div className="mt-4">
            <button className="btn-primary" type="submit" disabled={submitting || properties.length === 0}>
              {submitting ? "Creating..." : "Create Unit"}
            </button>
          </div>
        </form>

        {loading ? <LoadingSpinner /> : (
          <div className="card">
            <table className="w-full">
              <thead className="border-b border-gray-200">
                <tr>
                  <th className="table-header">Unit</th>
                  <th className="table-header">Property</th>
                  <th className="table-header">Size</th>
                  <th className="table-header">Rate</th>
                  <th className="table-header">Tier</th>
                  <th className="table-header">Purpose</th>
                  <th className="table-header">Status</th>
                  <th className="table-header">Available</th>
                  <th className="table-header"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {units.map((u) => {
                  const editing = editingId === u.id;
                  return (
                    <tr key={u.id} className="hover:bg-gray-50 align-top">
                      <td className="table-cell">
                        {editing ? (
                          <input className="form-input" value={form.unit_number}
                            onChange={(e) => setForm({ ...form, unit_number: e.target.value })} />
                        ) : u.unit_number}
                      </td>
                      <td className="table-cell">{u.property?.name}</td>
                      <td className="table-cell">
                        {editing ? (
                          <input type="number" className="form-input" value={form.size}
                            onChange={(e) => setForm({ ...form, size: e.target.value })} />
                        ) : `${u.size} sq ft`}
                      </td>
                      <td className="table-cell">
                        {editing ? (
                          <input type="number" className="form-input" value={form.rental_rate}
                            onChange={(e) => setForm({ ...form, rental_rate: e.target.value })} />
                        ) : `$${parseFloat(u.rental_rate || 0).toLocaleString()}`}
                      </td>
                      <td className="table-cell">
                        {editing ? (
                          <select className="form-select" value={form.tier}
                            onChange={(e) => setForm({ ...form, tier: e.target.value })}>
                            <option value="standard">Standard</option>
                            <option value="premium">Premium</option>
                            <option value="anchor">Anchor</option>
                          </select>
                        ) : <span className="capitalize">{u.tier}</span>}
                      </td>
                      <td className="table-cell">
                        {editing ? (
                          <select className="form-select" value={form.purpose}
                            onChange={(e) => setForm({ ...form, purpose: e.target.value })}>
                            <option value="retail">Retail</option>
                            <option value="food">Food</option>
                            <option value="services">Services</option>
                          </select>
                        ) : <span className="capitalize">{u.purpose}</span>}
                      </td>
                      <td className="table-cell">
                        {editing ? (
                          <select className="form-select" value={form.status}
                            onChange={(e) => setForm({ ...form, status: e.target.value })}>
                            <option value="available">Available</option>
                            <option value="occupied">Occupied</option>
                            <option value="under_maintenance">Under Maintenance</option>
                          </select>
                        ) : <StatusBadge status={u.status} />}
                      </td>
                      <td className="table-cell">
                        {editing ? (
                          <input
                            type="checkbox"
                            checked={form.available}
                            onChange={(e) => setForm({ ...form, available: e.target.checked })}
                          />
                        ) : (u.available ? "Yes" : "No")}
                      </td>
                      <td className="table-cell">
                        {editing ? (
                          <div className="flex gap-2">
                            <button className="btn-success text-xs py-1 px-2" disabled={submitting} onClick={saveEdit}>
                              {submitting ? "Saving..." : "Save"}
                            </button>
                            <button className="btn-secondary text-xs py-1 px-2" onClick={cancelEdit}>Cancel</button>
                          </div>
                        ) : (
                          <button className="text-blue-600 hover:underline text-sm" onClick={() => beginEdit(u)}>
                            Edit
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}
