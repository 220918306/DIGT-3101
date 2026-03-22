const STATUS_COLORS = {
  // Invoice statuses
  paid:            "bg-green-100 text-green-800",
  unpaid:          "bg-yellow-100 text-yellow-800",
  partially_paid:  "bg-orange-100 text-orange-800",
  overdue:         "bg-red-100 text-red-800",
  // Lease statuses
  active:          "bg-green-100 text-green-800",
  expired:         "bg-gray-100 text-gray-800",
  terminated:      "bg-red-100 text-red-800",
  renewed:         "bg-blue-100 text-blue-800",
  // Application statuses
  pending:         "bg-yellow-100 text-yellow-800",
  under_review:    "bg-blue-100 text-blue-800",
  approved:        "bg-green-100 text-green-800",
  rejected:        "bg-red-100 text-red-800",
  cancelled:       "bg-gray-100 text-gray-800",
  // Ticket priority
  emergency:       "bg-red-100 text-red-800",
  urgent:          "bg-orange-100 text-orange-800",
  routine:         "bg-gray-100 text-gray-600",
  // Ticket status
  open:            "bg-yellow-100 text-yellow-800",
  in_progress:     "bg-blue-100 text-blue-800",
  completed:       "bg-green-100 text-green-800",
  // Unit status
  available:       "bg-green-100 text-green-800",
  occupied:        "bg-blue-100 text-blue-800",
  under_maintenance: "bg-yellow-100 text-yellow-800",
  // Appointment
  confirmed:       "bg-green-100 text-green-800",
  // Letters
  sent:            "bg-yellow-100 text-yellow-800",
  signed:          "bg-green-100 text-green-800",
};

export default function StatusBadge({ status }) {
  const color = STATUS_COLORS[status] || "bg-gray-100 text-gray-600";
  const label = status?.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${color}`}>
      {label}
    </span>
  );
}
