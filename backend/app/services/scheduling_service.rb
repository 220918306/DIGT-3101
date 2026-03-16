class SchedulingService
  # FR-03: Check for time slot conflicts
  def check_conflict(unit_id, datetime)
    Appointment.where(unit_id: unit_id, scheduled_time: datetime)
               .where.not(status: "cancelled")
               .exists?
  end

  # FR-03: Book appointment with pessimistic locking (NFR-08 race condition prevention)
  def book_appointment(params)
    ActiveRecord::Base.transaction do
      unit = Unit.lock("FOR UPDATE").find(params[:unit_id])
      raise ConflictError, "Unit not available" unless unit.available?
      raise ConflictError, "Time slot taken" if check_conflict(params[:unit_id], params[:scheduled_time])

      appointment = Appointment.create!(
        unit_id:        params[:unit_id],
        tenant_id:      params[:tenant_id],
        scheduled_time: params[:scheduled_time],
        status:         "confirmed"
      )
      NotificationService.new.send_booking_confirmation(appointment)
      appointment
    end
  end

  # FR-03: Return available hour slots for a unit on a given date
  def available_slots(unit_id, date)
    booked = Appointment.where(unit_id: unit_id)
                        .where("DATE(scheduled_time) = ?", date)
                        .where.not(status: "cancelled")
                        .pluck(:scheduled_time)
                        .map(&:hour)
    (9..17).to_a - booked
  end
end
