class Api::V1::InvoicesController < Api::V1::BaseController
  # GET /api/v1/invoices — FR-07: List invoices
  def index
    invoices = if current_user.tenant?
                 Invoice.where(tenant_id: current_user.tenant.id)
               else
                 Invoice.includes(:tenant, :lease)
               end
    invoices = invoices.where(status: params[:status]) if params[:status].present?
    invoices = invoices.order(created_at: :desc)
    render json: invoices.map { |i| invoice_json(i) }
  end

  # GET /api/v1/invoices/:id — FR-12: Detailed invoice with line items
  def show
    invoice = Invoice.includes(:invoice_line_items, :payments).find(params[:id])
    return if authorize_invoice_access!(invoice)
    render json: invoice_json(invoice).merge(
      line_items: invoice.invoice_line_items.map { |li| line_item_json(li) },
      payments:   invoice.payments.map { |p| payment_json(p) }
    )
  end

  # POST /api/v1/invoices/generate — FR-07: Clerk manually triggers generation
  def generate
    authorize_roles!("clerk", "admin")
    count = BillingService.new.generate_monthly_invoices
    render json: { message: "Generated #{count} invoice(s) for active leases" }
  end

  private

  def authorize_invoice_access!(invoice)
    return false if current_user.clerk? || current_user.admin?
    return false if current_user.tenant? && invoice.tenant_id == current_user.tenant&.id

    render json: { error: "Forbidden" }, status: :forbidden
    true
  end

  def invoice_json(i)
    {
      id:            i.id,
      lease_id:      i.lease_id,
      tenant_id:     i.tenant_id,
      amount:        i.amount,
      amount_paid:   i.amount_paid,
      remaining:     i.remaining_balance,
      status:        i.status,
      due_date:      i.due_date,
      billing_month: i.billing_month,
      reminder_count: i.reminder_count
    }
  end

  def line_item_json(li)
    { id: li.id, item_type: li.item_type, description: li.description, amount: li.amount }
  end

  def payment_json(p)
    { id: p.id, amount: p.amount, payment_method: p.payment_method,
      transaction_id: p.transaction_id, status: p.status, created_at: p.created_at }
  end
end
