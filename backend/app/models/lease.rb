class Lease < ApplicationRecord
  belongs_to :tenant
  belongs_to :unit
  belongs_to :application, optional: true

  has_many :invoices, dependent: :destroy
  has_many :letters, dependent: :destroy
  has_many :utility_consumptions, dependent: :destroy
  has_many :maintenance_tickets, dependent: :destroy

  enum :status,        { active: "active", expired: "expired", terminated: "terminated", renewed: "renewed" }
  enum :payment_cycle, { monthly: "monthly", quarterly: "quarterly", biannual: "biannual", annual: "annual" }

  validates :start_date, :end_date, :rent_amount, presence: true
  validates :rent_amount, numericality: { greater_than: 0 }

  def active?
    status == "active" && end_date >= Date.today
  end

  def next_invoice_due?
    return true if invoices.none?

    last_invoice = invoices.order(:billing_month).last
    months_since = case payment_cycle
                   when "monthly"   then 1
                   when "quarterly" then 3
                   when "biannual"  then 6
                   when "annual"    then 12
                   else 1
                   end
    last_invoice.billing_month <= months_since.months.ago.to_date
  end

  def calculate_discounted_rent
    rent_amount * (1 - discount_rate / 100)
  end
end
