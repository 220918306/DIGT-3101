class Api::V1::InvoicesController < Api::V1::BaseController
  # GET /api/v1/invoices — FR-07: List invoices
  def index
    invoices = if current_user.tenant?
                 Invoice.where(tenant_id: current_user.tenant.id).includes(:invoice_line_items)
               else
                 Invoice.includes(:tenant, :lease, :invoice_line_items)
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

  # POST /api/v1/invoices/regenerate — FR-07: Regenerate invoice for one lease (replace or add for same billing month)
  def regenerate
    authorize_roles!("clerk", "admin")
    lease_id = params.require(:lease_id)
    replace  = ActiveModel::Type::Boolean.new.cast(params.fetch(:replace_existing, false))

    invoice = BillingService.new.regenerate_invoice_for_lease(lease_id, replace_existing: replace)
    render json: invoice_json(invoice).merge(
      line_items: invoice.invoice_line_items.map { |li| line_item_json(li) }
    ), status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Lease not found" }, status: :not_found
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue BillingService::ReplaceInvoiceBlockedError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH /api/v1/invoices/:id/utilities — clerk/admin: set monthly utility line items (not damage invoices)
  def utilities
    authorize_roles!("clerk", "admin")
    invoice = Invoice.includes(:invoice_line_items).find(params[:id])

    if invoice.invoice_line_items.any?(&:damage?)
      return render json: {
        error: "Utility charges can only be edited on regular monthly invoices, not maintenance damage bills."
      }, status: :unprocessable_entity
    end

    p = utilities_params.to_h.stringify_keys
    unless %w[electricity water waste].all? { |k| p.key?(k) }
      return render json: { error: "Provide electricity, water, and waste amounts." }, status: :bad_request
    end

    ActiveRecord::Base.transaction do
      apply_utility_amount!(invoice, "electricity", "Electricity", p["electricity"])
      apply_utility_amount!(invoice, "water", "Water", p["water"])
      apply_utility_amount!(invoice, "waste", "Waste Management", p["waste"])

      new_total = invoice.invoice_line_items.sum(:amount)
      if invoice.amount_paid.to_d > new_total
        invoice.errors.add(:base, "New total cannot be less than amount already paid ($#{invoice.amount_paid}).")
        raise ActiveRecord::RecordInvalid.new(invoice)
      end

      invoice.amount = new_total
      invoice.status = derive_status_after_total_change(invoice)
      invoice.save!
    end

    invoice.reload
    render json: invoice_json(invoice).merge(
      line_items: invoice.invoice_line_items.map { |li| line_item_json(li) }
    )
  end

  private

  def utilities_params
    params.permit(:electricity, :water, :waste)
  end

  def apply_utility_amount!(invoice, item_type, label, raw)
    amount = BigDecimal(raw.to_s)
    if amount.negative?
      invoice.errors.add(:base, "Amounts must be zero or greater")
      raise ActiveRecord::RecordInvalid.new(invoice)
    end

    li = invoice.invoice_line_items.find { |i| i.item_type == item_type }
    if li
      li.update!(description: label, amount: amount)
    else
      invoice.invoice_line_items.create!(item_type: item_type, description: label, amount: amount)
    end
  end

  def derive_status_after_total_change(invoice)
    paid = invoice.amount_paid.to_d
    total = invoice.amount.to_d
    base = if paid >= total
             "paid"
           elsif paid.positive?
             "partially_paid"
           else
             "unpaid"
           end
    if invoice.due_date < Date.today && base.in?(%w[unpaid partially_paid])
      "overdue"
    else
      base
    end
  end

  def authorize_invoice_access!(invoice)
    return false if current_user.clerk? || current_user.admin?
    return false if current_user.tenant? && invoice.tenant_id == current_user.tenant&.id

    render json: { error: "Forbidden" }, status: :forbidden
    true
  end

  def invoice_json(i)
    util = utility_amounts_from_line_items(i.invoice_line_items)
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
      reminder_count: i.reminder_count,
      utilities_editable: i.invoice_line_items.none?(&:damage?),
      utility_electricity: util["electricity"],
      utility_water:       util["water"],
      utility_waste:       util["waste"]
    }
  end

  def utility_amounts_from_line_items(items)
    base = { "electricity" => 0.0, "water" => 0.0, "waste" => 0.0 }
    items.each do |li|
      key = li.item_type.to_s
      base[key] = li.amount.to_f if base.key?(key)
    end
    base
  end

  def line_item_json(li)
    { id: li.id, item_type: li.item_type, description: li.description, amount: li.amount }
  end

  def payment_json(p)
    { id: p.id, amount: p.amount, payment_method: p.payment_method,
      transaction_id: p.transaction_id, status: p.status, created_at: p.created_at }
  end
end
