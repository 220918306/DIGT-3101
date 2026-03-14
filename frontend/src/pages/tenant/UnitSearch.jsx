import { useState, useEffect } from "react";
import { getUnits, getAvailableSlots } from "../../api/units";
import { createAppointment } from "../../api/appointments";
import { createApplication } from "../../api/applications";
import Navbar from "../../components/Navbar";
import StatusBadge from "../../components/shared/StatusBadge";
import LoadingSpinner from "../../components/shared/LoadingSpinner";

function UnitCard({ unit, onBook, onApply }) {
  return (
    <div className="card hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between mb-3">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">Unit {unit.unit_number}</h3>
          <p className="text-sm text-gray-500">{unit.property?.name} — {unit.property?.address}</p>
        </div>
        <StatusBadge status={unit.status} />
      </div>
      <div className="grid grid-cols-3 gap-3 mb-4 text-center">
        <div className="bg-gray-50 rounded-lg p-2">
          <p className="text-xs text-gray-500">Size</p>
          <p className="text-sm font-semibold">{unit.size} sq ft</p>
        </div>
        <div className="bg-gray-50 rounded-lg p-2">
          <p className="text-xs text-gray-500">Rate</p>
          <p className="text-sm font-semibold">${parseFloat(unit.rental_rate).toLocaleString()}/mo</p>
        </div>
        <div className="bg-gray-50 rounded-lg p-2">
          <p className="text-xs text-gray-500">Tier</p>
          <p className="text-sm font-semibold capitalize">{unit.tier}</p>
        </div>
      </div>
      <div className="flex gap-2">
        <span className="inline-flex items-center px-2 py-1 bg-indigo-50 text-indigo-700 text-xs rounded-md capitalize">{unit.purpose}</span>
      </div>
      {unit.available && (
        <div className="flex gap-2 mt-4">
          <button onClick={() => onBook(unit)} className="btn-secondary flex-1 text-sm py-1.5">📅 Book Viewing</button>
          <button onClick={() => onApply(unit)} className="btn-primary flex-1 text-sm py-1.5">Apply</button>
        </div>
      )}
    </div>
  );
}

export default function UnitSearch() {
  const [units, setUnits]       = useState([]);
  const [filters, setFilters]   = useState({ available_only: "true", min_price: "", max_price: "", tier: "", purpose: "" });
  const [loading, setLoading]   = useState(true);
  const [selectedUnit, setSelectedUnit] = useState(null);
  const [modal, setModal]       = useState(null); // "book" | "apply"
  const [slots, setSlots]       = useState([]);
  const [bookDate, setBookDate] = useState("");
  const [bookHour, setBookHour] = useState("");
  const [applyData, setApplyData] = useState({ employment_info: "", business_type: "" });
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage]   = useState("");

  const fetchUnits = () => {
    setLoading(true);
    getUnits(filters)
      .then((r) => setUnits(r.data))
      .finally(() => setLoading(false));
  };

  useEffect(() => { fetchUnits(); }, []); // eslint-disable-line

  const handleBook = async (unit) => {
    setSelectedUnit(unit);
    setModal("book");
    setSlots([]);
    setBookDate("");
  };

  const handleLoadSlots = async () => {
    if (!bookDate) return;
    const r = await getAvailableSlots(selectedUnit.id, bookDate);
    setSlots(r.data.available_slots || []);
  };

  const handleConfirmBook = async () => {
    if (!bookDate || !bookHour) return;
    setSubmitting(true);
    try {
      const dt = `${bookDate}T${String(bookHour).padStart(2, "0")}:00:00`;
      await createAppointment({ unit_id: selectedUnit.id, scheduled_time: dt });
      setMessage("Appointment booked successfully!");
      setModal(null);
    } catch (err) {
      setMessage(err.response?.data?.error || "Booking failed.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleApply = (unit) => {
    setSelectedUnit(unit);
    setModal("apply");
    setApplyData({ employment_info: "", business_type: "" });
  };

  const handleSubmitApplication = async () => {
    setSubmitting(true);
    try {
      await createApplication({
        unit_id:          selectedUnit.id,
        employment_info:  applyData.employment_info,
        application_data: { business_type: applyData.business_type },
      });
      setMessage("Application submitted! A clerk will review it shortly.");
      setModal(null);
    } catch (err) {
      setMessage(err.response?.data?.errors?.join(", ") || "Application failed.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Navbar />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-2xl font-bold text-gray-900 mb-6">Find Available Units</h1>

        {message && (
          <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg text-green-700 text-sm flex justify-between">
            {message}
            <button onClick={() => setMessage("")} className="ml-4 text-green-500 hover:text-green-700">✕</button>
          </div>
        )}

        {/* Filters */}
        <div className="card mb-6">
          <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
            <div>
              <label className="form-label">Min Price</label>
              <input type="number" className="form-input" placeholder="$0"
                value={filters.min_price} onChange={(e) => setFilters({ ...filters, min_price: e.target.value })} />
            </div>
            <div>
              <label className="form-label">Max Price</label>
              <input type="number" className="form-input" placeholder="$10,000"
                value={filters.max_price} onChange={(e) => setFilters({ ...filters, max_price: e.target.value })} />
            </div>
            <div>
              <label className="form-label">Tier</label>
              <select className="form-select" value={filters.tier} onChange={(e) => setFilters({ ...filters, tier: e.target.value })}>
                <option value="">All Tiers</option>
                <option value="standard">Standard</option>
                <option value="premium">Premium</option>
                <option value="anchor">Anchor</option>
              </select>
            </div>
            <div>
              <label className="form-label">Purpose</label>
              <select className="form-select" value={filters.purpose} onChange={(e) => setFilters({ ...filters, purpose: e.target.value })}>
                <option value="">All</option>
                <option value="retail">Retail</option>
                <option value="food">Food</option>
                <option value="services">Services</option>
              </select>
            </div>
            <div className="flex items-end">
              <button className="btn-primary w-full" onClick={fetchUnits}>Search</button>
            </div>
          </div>
        </div>

        {loading ? <LoadingSpinner /> : (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            {units.length === 0 ? (
              <div className="col-span-3 text-center py-16 text-gray-500">
                <p className="text-4xl mb-3">🏬</p>
                <p className="text-lg font-medium">No units found matching your criteria</p>
              </div>
            ) : units.map((unit) => (
              <UnitCard key={unit.id} unit={unit} onBook={handleBook} onApply={handleApply} />
            ))}
          </div>
        )}

        {/* Book Viewing Modal */}
        {modal === "book" && selectedUnit && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
              <h3 className="text-lg font-semibold mb-4">Book Viewing — Unit {selectedUnit.unit_number}</h3>
              <div className="space-y-3">
                <div>
                  <label className="form-label">Select Date</label>
                  <input type="date" className="form-input" value={bookDate}
                    min={new Date().toISOString().split("T")[0]}
                    onChange={(e) => setBookDate(e.target.value)} />
                </div>
                <button className="btn-secondary w-full text-sm" onClick={handleLoadSlots}>Check Available Times</button>
                {slots.length > 0 && (
                  <div>
                    <label className="form-label">Available Time Slots</label>
                    <div className="grid grid-cols-4 gap-2">
                      {slots.map((h) => (
                        <button key={h} onClick={() => setBookHour(h)}
                          className={`py-2 text-sm rounded-lg border transition-colors ${bookHour === h ? "bg-blue-600 text-white border-blue-600" : "border-gray-300 hover:border-blue-400"}`}>
                          {h}:00
                        </button>
                      ))}
                    </div>
                  </div>
                )}
              </div>
              <div className="flex gap-2 mt-5">
                <button className="btn-secondary flex-1" onClick={() => setModal(null)}>Cancel</button>
                <button className="btn-primary flex-1" onClick={handleConfirmBook} disabled={submitting || !bookHour}>
                  {submitting ? "Booking..." : "Confirm"}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Apply Modal */}
        {modal === "apply" && selectedUnit && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
              <h3 className="text-lg font-semibold mb-4">Apply for Unit {selectedUnit.unit_number}</h3>
              <p className="text-sm text-gray-500 mb-4">
                Rate: <strong>${parseFloat(selectedUnit.rental_rate).toLocaleString()}/mo</strong>
              </p>
              <div className="space-y-3">
                <div>
                  <label className="form-label">Business Type</label>
                  <input type="text" className="form-input" placeholder="e.g. Coffee Shop"
                    value={applyData.business_type}
                    onChange={(e) => setApplyData({ ...applyData, business_type: e.target.value })} />
                </div>
                <div>
                  <label className="form-label">Employment / Business Info</label>
                  <textarea className="form-input" rows={3} placeholder="Describe your business and financials..."
                    value={applyData.employment_info}
                    onChange={(e) => setApplyData({ ...applyData, employment_info: e.target.value })} />
                </div>
              </div>
              <div className="flex gap-2 mt-5">
                <button className="btn-secondary flex-1" onClick={() => setModal(null)}>Cancel</button>
                <button className="btn-primary flex-1" onClick={handleSubmitApplication} disabled={submitting}>
                  {submitting ? "Submitting..." : "Submit Application"}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  );
}
