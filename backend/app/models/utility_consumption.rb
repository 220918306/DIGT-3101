class UtilityConsumption < ApplicationRecord
  belongs_to :lease

  validates :billing_period, presence: true
  validates :billing_period, uniqueness: { scope: :lease_id }
end
