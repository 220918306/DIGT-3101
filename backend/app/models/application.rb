class Application < ApplicationRecord
  belongs_to :tenant
  belongs_to :unit
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_one :lease

  enum :status, {
    pending:      "pending",
    under_review: "under_review",
    approved:     "approved",
    rejected:     "rejected",
    cancelled:    "cancelled"
  }

  validates :application_date, presence: true
end
