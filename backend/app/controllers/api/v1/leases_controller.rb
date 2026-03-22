class Api::V1::LeasesController < Api::V1::BaseController
  # GET /api/v1/leases — FR-06: List leases
  def index
    leases = if current_user.tenant?
      Lease.includes(:unit, :letters).where(tenant_id: current_user.tenant.id)
    else
      scope = Lease.includes(:tenant, :unit, :letters)
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
      auto_renew:    old_lease.auto_renew,
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

  # PATCH /api/v1/leases/:id — Clerk/admin updates lease terms
  def update
    authorize_roles!("admin")
    lease = Lease.find(params[:id])
    lease.update!(lease_update_params)
    render json: lease_json(lease)
  end

  # POST /api/v1/leases/:id/send_agreement — mock agreement dispatch
  def send_agreement
    authorize_roles!("clerk", "admin")
    lease = Lease.find(params[:id])
    latest = lease.letters.where(letter_type: "lease_agreement").order(created_at: :desc).first
    if latest&.signed?
      return render json: { error: "Lease agreement already signed by tenant" }, status: :unprocessable_entity
    end
    if latest&.sent?
      return render json: { error: "Lease agreement already sent and awaiting signature" }, status: :unprocessable_entity
    end

    body = <<~TEXT
      Dear Tenant,

      This letter confirms your lease agreement for Unit #{lease.unit_id}.
      Lease term: #{lease.start_date} to #{lease.end_date}.
      Monthly rent: $#{lease.rent_amount}.
      Payment cycle: #{lease.payment_cycle}.
      Auto-renew: #{lease.auto_renew ? "Enabled" : "Disabled"}.

      By signing this agreement, you acknowledge and accept these lease terms.

      Regards,
      REMS Leasing Team
    TEXT

    Letter.create!(
      tenant_id: lease.tenant_id,
      lease_id: lease.id,
      letter_type: "lease_agreement",
      status: "sent",
      subject: "Lease Agreement for Unit #{lease.unit_id}",
      body: body,
      sent_at: Time.current
    )
    Rails.logger.info("[LEASE_AGREEMENT] Created lease agreement letter for lease ##{lease.id}")
    render json: { message: "Lease agreement sent", lease_id: lease.id }
  end

  private

  def lease_params
    params.permit(:tenant_id, :unit_id, :application_id, :start_date, :end_date,
                  :rent_amount, :payment_cycle, :discount_rate, :auto_renew)
          .merge(status: "active")
  end

  def lease_update_params
    params.permit(:end_date, :status, :auto_renew)
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
      auto_renew:   l.auto_renew,
      discount_rate: l.discount_rate,
      status:        l.status,
      agreement_signed: agreement_signed?(l),
      agreement_status: agreement_status_for(l),
      unit_number:   l.unit&.unit_number,
      tenant_name:   l.tenant&.user&.name
    }
  end

  def agreement_signed?(lease)
    lease.letters.any? { |letter| letter.letter_type == "lease_agreement" && letter.signed? }
  end

  def agreement_status_for(lease)
    letter = lease.letters.select { |l| l.letter_type == "lease_agreement" }.max_by(&:created_at)
    letter&.status || "none"
  end
end
