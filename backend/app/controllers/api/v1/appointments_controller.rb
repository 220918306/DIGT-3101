class Api::V1::AppointmentsController < Api::V1::BaseController
  # GET /api/v1/appointments — FR-03: List tenant's appointments
  def index
    tenant       = current_user.tenant
    appointments = Appointment.includes(:unit).where(tenant_id: tenant.id).order(:scheduled_time)
    render json: appointments.map { |a| appointment_json(a) }
  end

  # POST /api/v1/appointments — FR-03: Book a viewing appointment
  def create
    authorize_roles!("tenant")
    tenant  = current_user.tenant
    service = SchedulingService.new

    appointment = service.book_appointment(
      unit_id:        params[:unit_id],
      tenant_id:      tenant.id,
      scheduled_time: DateTime.parse(params[:scheduled_time])
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
      unit_number:    a.unit&.unit_number
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
