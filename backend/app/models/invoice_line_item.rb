class InvoiceLineItem < ApplicationRecord
  belongs_to :invoice

  enum :item_type, {
    rent:        "rent",
    electricity: "electricity",
    water:       "water",
    waste:       "waste",
    discount:    "discount",
    damage:      "damage"
  }

  validates :amount, :item_type, presence: true
end
