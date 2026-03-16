class Api::V1::ApplicationsController < Api::V1::BaseController
  # GET /api/v1/applications — FR-04/FR-05: List applications
  def index
    apps = if current_user.tenant?
             Application.includes(:unit).where(tenant_id: current_user.tenant.id)
           else
             scope = Application.includes(:tenant, :unit)
             scope = scope.where(status: params[:status]) if params[:status].present?
             scope
           end
    render json: apps.map { |a| application_json(a) }
  end

  # POST /api/v1/applications — FR-04: Submit lease application
  def create
    authorize_roles!("tenant")

    app = Application.create!(
      tenant_id:        current_user.tenant.id,
      unit_id:          params[:unit_id],
      application_data: params[:application_data] || {},
      employment_info:  params[:employment_info],
      application_date: Date.today,
      status:           "pending"
    )
    render json: application_json(app), status: :created
  end

  # PATCH /api/v1/applications/:id/approve — FR-05: Clerk approves application
  def approve
    authorize_roles!("clerk", "admin")
    app = Application.find(params[:id])

    unless %w[pending under_review].include?(app.status)
      return render json: { error: "Application already processed" }, status: :unprocessable_entity
    end

    lease = LeaseFactory.create_from_application(app, lease_params)
    render json: { application: application_json(app.reload), lease: lease_json(lease) }
  end

  # DELETE /api/v1/applications/:id — TC-22: Tenant cancels their own pending application
  def destroy
    authorize_roles!("tenant")
    app = Application.find(params[:id])

    unless app.tenant_id == current_user.tenant&.id
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    unless app.status == "pending"
      return render json: { error: "Only pending applications can be cancelled" }, status: :unprocessable_entity
    end

    app.update!(status: "cancelled", cancelled_at: Time.current)
    render json: application_json(app)
  end

  # PATCH /api/v1/applications/:id/reject — FR-05: Clerk rejects application
  def reject
    authorize_roles!("clerk", "admin")
    app = Application.find(params[:id])
    app.update!(status: "rejected", rejection_reason: params[:reason],
                reviewed_by_id: current_user.id)
    render json: application_json(app)
  end

  private

  def lease_params
    params.permit(:start_date, :end_date, :rent_amount, :payment_cycle)
  end

  def application_json(a)
    {
      id:               a.id,
      tenant_id:        a.tenant_id,
      unit_id:          a.unit_id,
      status:           a.status,
      application_date: a.application_date,
      application_data: a.application_data,
      employment_info:  a.employment_info,
      rejection_reason: a.rejection_reason,
      approved_at:      a.approved_at,
      unit_number:      a.unit&.unit_number
    }
  end

  def lease_json(l)
    {
      id:           l.id,
      tenant_id:    l.tenant_id,
      unit_id:      l.unit_id,
      start_date:   l.start_date,
      end_date:     l.end_date,
      rent_amount:  l.rent_amount,
      payment_cycle: l.payment_cycle,
      status:       l.status
    }
  end
end
