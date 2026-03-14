class Api::V1::LeasesController < Api::V1::BaseController
  # GET /api/v1/leases — FR-06: List leases
  def index
    leases = if current_user.tenant?
               Lease.includes(:unit).where(tenant_id: current_user.tenant.id)
             else
               scope = Lease.includes(:tenant, :unit)
               scope = scope.where(status: params[:status]) if params[:status].present?
               scope
             end
    render json: leases.map { |l| lease_json(l) }
  end

  # GET /api/v1/leases/:id
  def show
    lease = Lease.includes(:unit, :tenant).find(params[:id])
    return if authorize_lease_access!(lease)
    render json: lease_json(lease)
  end

  # POST /api/v1/leases — FR-06: Clerk creates lease directly
  def create
    authorize_roles!("clerk", "admin")
    lease = Lease.create!(lease_params)
    lease.unit.mark_as_occupied!
    NotificationService.new.send_lease_created(lease)
    render json: lease_json(lease), status: :created
  end

  private

  def lease_params
    params.permit(:tenant_id, :unit_id, :application_id, :start_date, :end_date,
                  :rent_amount, :payment_cycle, :discount_rate)
          .merge(status: "active")
  end

  def authorize_lease_access!(lease)
    return false if current_user.clerk? || current_user.admin?
    return false if current_user.tenant? && lease.tenant_id == current_user.tenant&.id

    render json: { error: "Forbidden" }, status: :forbidden
    true
  end

  def lease_json(l)
    {
      id:            l.id,
      tenant_id:     l.tenant_id,
      unit_id:       l.unit_id,
      application_id: l.application_id,
      start_date:    l.start_date,
      end_date:      l.end_date,
      rent_amount:   l.rent_amount,
      payment_cycle: l.payment_cycle,
      discount_rate: l.discount_rate,
      status:        l.status,
      unit_number:   l.unit&.unit_number,
      tenant_name:   l.tenant&.user&.name
    }
  end
end
