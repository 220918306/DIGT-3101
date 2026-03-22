class Api::V1::AppointmentsController < Api::V1::BaseController
  # GET /api/v1/appointments — FR-03: List tenant's appointments
  def index
    appointments = if current_user.tenant?
      Appointment.includes(:unit).where(tenant_id: current_user.tenant.id)
    else
      scope = Appointment.includes(:unit, tenant: :user)
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope
    end
    appointments = appointments.order(:scheduled_time)
    render json: appointments.map { |a| appointment_json(a) }
  end

  # POST /api/v1/appointments — FR-03: Book a viewing appointment
  def create
    authorize_roles!("tenant")
    tenant  = current_user.tenant
    service = SchedulingService.new
    scheduled_time = DateTime.parse(params[:scheduled_time])

    if scheduled_time < 24.hours.from_now
      return render json: { error: "Viewing must be booked at least 24 hours in advance" }, status: :unprocessable_entity
    end

    appointment = service.book_appointment(
      unit_id:        params[:unit_id],
      tenant_id:      tenant.id,
      scheduled_time:
    )
    render json: appointment_json(appointment), status: :created
  rescue ConflictError => e
    slots = SchedulingService.new.available_slots(params[:unit_id], Date.parse(params[:scheduled_time].to_s))
    render json: { error: e.message, next_available_slots: slots }, status: :conflict
  rescue ArgumentError
    render json: { error: "Invalid datetime format" }, status: :bad_request
  end

  # PATCH /api/v1/appointments/:id — FR-03: Reschedule appointment
  def update
    appointment = Appointment.find(params[:id])
    if current_user.clerk? || current_user.admin?
      status = params[:status].to_s
      unless %w[confirmed rejected].include?(status)
        return render json: { error: "Invalid status update" }, status: :unprocessable_entity
      end

      appointment.update!(status:)
      return render json: appointment_json(appointment)
    end

    authorize_tenant_owns!(appointment) && return

    appointment.update!(scheduled_time: DateTime.parse(params[:scheduled_time]))
    render json: appointment_json(appointment)
  rescue ArgumentError
    render json: { error: "Invalid datetime format" }, status: :bad_request
  end

  # DELETE /api/v1/appointments/:id — FR-03: Cancel appointment
  def destroy
    appointment = Appointment.find(params[:id])
    authorize_tenant_owns!(appointment) && return
    unless appointment.status == "pending"
      return render json: { error: "Only pending viewings can be cancelled" }, status: :unprocessable_entity
    end

    appointment.update!(status: "cancelled")
    render json: { message: "Appointment cancelled successfully" }
  end

  private

  def appointment_json(a)
    {
      id:             a.id,
      unit_id:        a.unit_id,
      tenant_id:      a.tenant_id,
      scheduled_time: a.scheduled_time,
      status:         a.status,
      unit_number:    a.unit&.unit_number,
      tenant_name:    a.tenant&.user&.name
    }
  end

  def authorize_tenant_owns!(appt)
    unless appt.tenant_id == current_user.tenant&.id
      render json: { error: "Forbidden" }, status: :forbidden
      return true
    end
    false
  end
end

class ConflictError < StandardError; end
