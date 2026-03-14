class Unit < ApplicationRecord
  belongs_to :property
  has_many :appointments, dependent: :destroy
  has_many :leases, dependent: :nullify
  has_many :applications, dependent: :nullify
  has_many :maintenance_tickets, dependent: :nullify

  enum :status, { available: "available", occupied: "occupied", under_maintenance: "under_maintenance" }
  enum :tier,   { standard: "standard", premium: "premium", anchor: "anchor" }
  enum :purpose, { retail: "retail", food: "food", services: "services" }

  validates :unit_number, presence: true, uniqueness: { scope: :property_id }
  validates :rental_rate, :size, numericality: { greater_than: 0 }, allow_nil: true

  scope :available_units, -> { where(available: true, status: "available") }
  scope :filter_by_price, ->(min, max) { where(rental_rate: min..max) }
  scope :filter_by_size,  ->(min, max) { where(size: min..max) }

  def mark_as_occupied!
    update!(status: "occupied", available: false)
  end

  def mark_as_available!
    update!(status: "available", available: true)
  end
end
