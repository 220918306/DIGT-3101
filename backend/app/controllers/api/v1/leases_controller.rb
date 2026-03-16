class Api::V1::LeasesController < Api::V1::BaseController
  # GET /api/v1/leases — FR-06: List leases
  def index
    leases = if current_user.tenant?
               Lease.includes(:unit).where(tenant_id: current_user.tenant.id)
             else
               scope = Lease.includes(:tenant, :unit)
               scope = scope.where(status: params[:status]) if params[:status].present?
               scope = scope.where(unit_id: params[:unit_id]) if params[:unit_id].present?
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

  # POST /api/v1/leases/:id/renew — TC-24: Clerk/admin renews an expiring lease
  def renew
    authorize_roles!("clerk", "admin")
    old_lease = Lease.find(params[:id])

    unless %w[active expiring].include?(old_lease.status)
      return render json: { error: "Only active or expiring leases can be renewed" },
                    status: :unprocessable_entity
    end

    new_end_date = params[:end_date].presence ||
                   (old_lease.end_date + (old_lease.end_date - old_lease.start_date) + 1.day)

    new_lease = Lease.create!(
      tenant_id:     old_lease.tenant_id,
      unit_id:       old_lease.unit_id,
      start_date:    old_lease.end_date + 1.day,
      end_date:      new_end_date,
      rent_amount:   params[:rent_amount].presence || old_lease.rent_amount,
      payment_cycle: old_lease.payment_cycle,
      status:        "active"
    )
    old_lease.update!(status: "expired")
    NotificationService.new.send_lease_created(new_lease)
    render json: lease_json(new_lease), status: :created
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
