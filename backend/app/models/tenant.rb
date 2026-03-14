class Tenant < ApplicationRecord
  belongs_to :user

  has_many :appointments, dependent: :destroy
  has_many :applications, dependent: :destroy
  has_many :leases, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :maintenance_tickets, dependent: :destroy

  delegate :name, :email, to: :user, prefix: false, allow_nil: true
end
