class MaintenanceTicket < ApplicationRecord
  belongs_to :lease
  belongs_to :tenant
  belongs_to :unit
  belongs_to :assigned_to, class_name: "User", optional: true

  enum :priority, { routine: "routine", urgent: "urgent", emergency: "emergency" }
  enum :status,   { open: "open", in_progress: "in_progress", completed: "completed", cancelled: "cancelled" }

  validates :description, :priority, :status, presence: true

  after_create :auto_escalate_if_emergency

  private

  def auto_escalate_if_emergency
    MaintenanceService.new.escalate_emergency(self) if emergency?
  end
end
