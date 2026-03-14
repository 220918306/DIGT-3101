class Appointment < ApplicationRecord
  belongs_to :unit
  belongs_to :tenant

  enum :status, { pending: "pending", confirmed: "confirmed", cancelled: "cancelled" }

  validates :scheduled_time, presence: true
  validate :no_time_conflict
  validate :within_business_hours

  private

  def no_time_conflict
    return unless unit_id && scheduled_time

    conflicts = Appointment.where(unit_id: unit_id, scheduled_time: scheduled_time)
                           .where.not(id: id)
                           .where.not(status: "cancelled")
    errors.add(:scheduled_time, "is already booked") if conflicts.exists?
  end

  def within_business_hours
    return unless scheduled_time

    hour = scheduled_time.hour
    errors.add(:scheduled_time, "must be between 9 AM and 6 PM") unless hour.between?(9, 17)
  end
end
