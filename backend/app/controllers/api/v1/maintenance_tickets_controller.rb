class Api::V1::MaintenanceTicketsController < Api::V1::BaseController
  # GET /api/v1/maintenance_tickets — FR-14/FR-18: Prioritized queue for clerks
  def index
    tickets = if current_user.tenant?
                MaintenanceTicket.where(tenant_id: current_user.tenant.id).order(created_at: :desc)
              else
                MaintenanceService.new.prioritized_queue
              end
    render json: tickets.map { |t| ticket_json(t) }
  end

  # POST /api/v1/maintenance_tickets — FR-09: Submit maintenance request
  def create
    authorize_roles!("tenant")
    lease = Lease.find_by!(tenant_id: current_user.tenant.id, status: "active")

    service = MaintenanceService.new
    ticket  = service.create_ticket(
      lease_id:    lease.id,
      tenant_id:   current_user.tenant.id,
      unit_id:     lease.unit_id,
      priority:    params[:priority] || "routine",
      description: params[:description],
      status:      "open"
    )
    render json: ticket_json(ticket), status: :created
  end

  # PATCH /api/v1/maintenance_tickets/:id — FR-14: Update ticket status
  def update
    authorize_roles!("clerk", "admin")
    ticket = MaintenanceTicket.find(params[:id])

    update_attrs = { status: params[:status] }
    update_attrs[:assigned_to_id] = params[:assigned_to_id] if params[:assigned_to_id].present?
    update_attrs[:resolved_at]    = Time.current if params[:status] == "completed"

    ticket.update!(update_attrs)
    render json: ticket_json(ticket)
  end

  # POST /api/v1/maintenance_tickets/:id/bill_damage — FR-15: Bill tenant for damage
  def bill_damage
    authorize_roles!("clerk", "admin")
    amount = params[:amount].to_f

    if amount <= 0
      return render json: { error: "Billing amount must be greater than zero" }, status: :unprocessable_entity
    end

    invoice = MaintenanceService.new.bill_for_damage(params[:id], amount, current_user)
    render json: {
      invoice_id: invoice.id,
      amount:     invoice.amount,
      due_date:   invoice.due_date,
      status:     invoice.status
    }, status: :created
  end

  private

  def ticket_json(t)
    {
      id:               t.id,
      lease_id:         t.lease_id,
      tenant_id:        t.tenant_id,
      unit_id:          t.unit_id,
      priority:         t.priority,
      status:           t.status,
      description:      t.description,
      is_tenant_caused: t.is_tenant_caused,
      billing_amount:   t.billing_amount,
      assigned_to_id:   t.assigned_to_id,
      resolved_at:      t.resolved_at,
      created_at:       t.created_at
    }
  end
end
