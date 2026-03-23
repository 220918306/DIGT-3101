class BillingService
  # FR-13 / FR-16: Multi-store discount — 10% when tenant has 3+ active leases (same billing cycle)
  DISCOUNT_TIERS = { 3 => 10.0 }.freeze

  class ReplaceInvoiceBlockedError < StandardError; end

  # FR-07: Automated monthly invoice generation (called by Sidekiq cron)
  def generate_monthly_invoices
    count = 0
    Lease.where(status: "active").find_each do |lease|
      next unless lease.next_invoice_due?
      next if invoice_exists_for_period?(lease)

      ActiveRecord::Base.transaction do
        build_invoice(lease)
        count += 1
      end
    rescue StandardError => e
      Rails.logger.error("Invoice generation failed for lease #{lease.id}: #{e.message}")
    end
    count
  end

  # FR-07 / FR-12: Build invoice with line items for transparency
  def build_invoice(lease)
    discount = calculate_discount(lease.tenant_id)
    utility  = UtilityService.new.get_charges(lease.id, Date.today.beginning_of_month)
    base     = lease.rent_amount

    invoice = Invoice.create!(
      lease_id:      lease.id,
      tenant_id:     lease.tenant_id,
      billing_month: Date.today.beginning_of_month,
      due_date:      Date.today.end_of_month,
      amount:        base - discount + utility[:total],
      status:        "unpaid"
    )

    invoice.invoice_line_items.create!(item_type: "rent",        description: "Base Rent",              amount: base)
    invoice.invoice_line_items.create!(item_type: "electricity", description: "Electricity Usage",      amount: utility[:electricity])
    invoice.invoice_line_items.create!(item_type: "water",       description: "Water Usage",            amount: utility[:water])
    invoice.invoice_line_items.create!(item_type: "waste",       description: "Waste Management",       amount: utility[:waste])
    if discount > 0
      invoice.invoice_line_items.create!(item_type: "discount",  description: "Multi-Store Discount",   amount: -discount)
    end

    lease.update!(discount_rate: discount_percentage(lease.tenant_id))
    NotificationService.new.send_invoice_generated(invoice)
    invoice
  end

  # FR-07: Manual regeneration for a single lease (TC-07 / TC-08 / TC-09 — replace vs add for same billing month)
  def regenerate_invoice_for_lease(lease_id, replace_existing:)
    lease = Lease.find(lease_id)
    raise ArgumentError, "Lease must be active" unless lease.status == "active"

    billing_month = Date.today.beginning_of_month
    existing        = Invoice.where(lease_id: lease.id, billing_month: billing_month)

    if existing.exists?
      if replace_existing
        if existing.any? { |inv| inv.amount_paid.to_f.positive? }
          raise ReplaceInvoiceBlockedError,
                "Cannot replace invoices that already have payments recorded."
        end
        existing.destroy_all
      else
        return build_invoice(lease)
      end
    end

    build_invoice(lease)
  end

  # FR-16: Calculate discount amount based on active lease count
  def calculate_discount(tenant_id)
    pct  = discount_percentage(tenant_id)
    return 0 if pct.zero?

    base = Lease.where(tenant_id: tenant_id, status: "active").first&.rent_amount || 0
    (base * (pct / 100.0)).round(2)
  end

  # FR-16: Return discount percentage for a tenant
  def discount_percentage(tenant_id)
    count = Lease.where(tenant_id: tenant_id, status: "active").count
    DISCOUNT_TIERS.select { |k, _| count >= k }.values.max || 0
  end

  private

  def invoice_exists_for_period?(lease)
    Invoice.where(lease_id: lease.id,
                  billing_month: Date.today.beginning_of_month).exists?
  end
end
