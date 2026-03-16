class Invoice < ApplicationRecord
  belongs_to :lease
  belongs_to :tenant

  has_many :invoice_line_items, dependent: :destroy
  has_many :payments, dependent: :destroy

  enum :status, {
    unpaid:          "unpaid",
    partially_paid:  "partially_paid",
    paid:            "paid",
    overdue:         "overdue"
  }

  validates :amount, :due_date, presence: true
  validates :amount, numericality: { greater_than: 0 }

  def remaining_balance
    amount - amount_paid
  end

  def mark_payment!(amount_received)
    self.amount_paid = (amount_paid || 0) + amount_received
    if self.amount_paid >= amount
      update!(amount_paid: self.amount_paid, status: "paid")
    elsif self.amount_paid > 0
      update!(amount_paid: self.amount_paid, status: "partially_paid")
    end
  end

  def overdue?
    due_date < Date.today && status.in?(%w[unpaid partially_paid])
  end
end
