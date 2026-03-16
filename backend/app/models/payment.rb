class Payment < ApplicationRecord
  belongs_to :invoice
  belongs_to :tenant

  enum :payment_method, { online: "online", manual: "manual", wire: "wire", check: "check" }
  enum :status,         { approved: "approved", declined: "declined" }

  validates :amount, numericality: { greater_than: 0 }
end
