require "test_helper"

class BillingServiceTest < ActiveSupport::TestCase
  setup do
    @property = create(:property)
    @unit      = create(:unit, :occupied, property: @property)
    @user      = create(:user)
    @tenant    = create(:tenant, user: @user)
    @lease     = create(:lease, tenant: @tenant, unit: @unit, rent_amount: 2500)
  end

  # TC-06: BillingService generates exactly one invoice per active lease due
  test "TC-06: generates one invoice per active lease" do
    assert_difference "Invoice.count", 1 do
      BillingService.new.generate_monthly_invoices
    end
  end

  # Idempotent monthly run — does not duplicate invoices for the same period
  test "generate_monthly_invoices does not duplicate invoices for same billing period" do
    BillingService.new.generate_monthly_invoices
    assert_no_difference "Invoice.count" do
      BillingService.new.generate_monthly_invoices
    end
  end

  # TC-08: Invoice includes line items for rent, utilities, and waste
  test "TC-08: invoice line items cover rent electricity water waste" do
    BillingService.new.generate_monthly_invoices
    invoice = Invoice.last
    types   = invoice.invoice_line_items.pluck(:item_type)
    assert_includes types, "rent",        "Should have rent line item"
    assert_includes types, "electricity", "Should have electricity line item"
    assert_includes types, "water",       "Should have water line item"
    assert_includes types, "waste",       "Should have waste line item"
  end

  # TC-09: Lease with expired status does not get an invoice
  test "TC-09: expired leases are skipped during invoice generation" do
    @lease.update!(status: "expired")
    assert_no_difference "Invoice.count" do
      BillingService.new.generate_monthly_invoices
    end
  end

  # TC-10: Full payment marks invoice as paid with zero balance
  test "TC-10: records full payment and marks invoice paid" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, amount: 2700, amount_paid: 0)
    invoice.mark_payment!(2700)
    assert_equal "paid",  invoice.status
    assert_equal 0,       invoice.remaining_balance
  end

  # Overpayment edge case (not TC-11 overdue spec)
  test "overpayment still marks invoice paid" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, amount: 2700, amount_paid: 0)
    invoice.mark_payment!(3000)
    assert_equal "paid", invoice.status
  end

  # TC-12: Partial payment updates status and remaining balance correctly
  test "TC-12: records partial payment with correct balance" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, amount: 2000, amount_paid: 0)
    invoice.mark_payment!(1000)
    assert_equal "partially_paid", invoice.status
    assert_equal 1000,             invoice.remaining_balance
  end

  # TC-27: 10% discount only when tenant has 3+ active leases (FR-13)
  test "TC-27: applies 10% discount for tenants with 3 active leases" do
    unit2 = create(:unit, :occupied, property: @property)
    unit3 = create(:unit, :occupied, property: @property)
    create(:lease, tenant: @tenant, unit: unit2, rent_amount: 1500)
    create(:lease, tenant: @tenant, unit: unit3, rent_amount: 1800)

    service = BillingService.new
    assert_equal 10.0, service.discount_percentage(@tenant.id)
  end

  test "TC-27b: two active leases do not receive multi-store discount" do
    unit2 = create(:unit, :occupied, property: @property)
    create(:lease, tenant: @tenant, unit: unit2, rent_amount: 2500)

    service = BillingService.new
    assert_equal 0.0, service.discount_percentage(@tenant.id)
  end

  # TC-28: after terminating one lease, tenant drops below 3 — no discount next calculation
  test "TC-28: discount removed when active lease count falls from 3 to 2" do
    unit2 = create(:unit, :occupied, property: @property)
    unit3 = create(:unit, :occupied, property: @property)
    lease2 = create(:lease, tenant: @tenant, unit: unit2, rent_amount: 1500)
    create(:lease, tenant: @tenant, unit: unit3, rent_amount: 1800)

    service = BillingService.new
    assert_equal 10.0, service.discount_percentage(@tenant.id)

    lease2.update!(status: "expired")
    assert_equal 0.0, service.discount_percentage(@tenant.id)
  end

  test "calculate_discount returns dollar amount for 3-lease multi-store tenant" do
    unit2 = create(:unit, :occupied, property: @property)
    unit3 = create(:unit, :occupied, property: @property)
    create(:lease, tenant: @tenant, unit: unit2, rent_amount: 2500)
    create(:lease, tenant: @tenant, unit: unit3, rent_amount: 2500)

    service = BillingService.new
    assert_equal 250.0, service.calculate_discount(@tenant.id)
  end

  # TC-33: Quarterly payment cycle — invoice skipped for months 2 & 3, generated on month 4
  test "TC-33a: quarterly lease skips invoicing in months 2 and 3 after last invoice" do
    @lease.update!(payment_cycle: "quarterly")
    # Billed at the start of the current month — 1 month ago means we're in month 2 (skip)
    create(:invoice, lease: @lease, tenant: @tenant,
           billing_month: 1.month.ago.to_date.beginning_of_month)

    assert_no_difference "Invoice.count",
                         "month 2 of quarterly cycle should be skipped" do
      BillingService.new.generate_monthly_invoices
    end
  end

  test "TC-33b: quarterly lease skips invoicing in month 3" do
    @lease.update!(payment_cycle: "quarterly")
    create(:invoice, lease: @lease, tenant: @tenant,
           billing_month: 2.months.ago.to_date.beginning_of_month)

    assert_no_difference "Invoice.count",
                         "month 3 of quarterly cycle should also be skipped" do
      BillingService.new.generate_monthly_invoices
    end
  end

  test "TC-33c: quarterly lease generates invoice on month 4 (3 months since last)" do
    @lease.update!(payment_cycle: "quarterly")
    create(:invoice, lease: @lease, tenant: @tenant,
           billing_month: 3.months.ago.to_date.beginning_of_month)

    assert_difference "Invoice.count", 1,
                      "month 4 of quarterly cycle should trigger new invoice" do
      BillingService.new.generate_monthly_invoices
    end
  end

  # TC-34: Annual payment cycle — invoice generated only once per 12 months
  test "TC-34a: annual lease skips invoicing when less than 12 months since last invoice" do
    @lease.update!(payment_cycle: "annual")
    create(:invoice, lease: @lease, tenant: @tenant,
           billing_month: 6.months.ago.to_date.beginning_of_month)

    assert_no_difference "Invoice.count",
                         "annual cycle: should skip after only 6 months" do
      BillingService.new.generate_monthly_invoices
    end
  end

  test "TC-34b: annual lease skips at 11 months since last invoice" do
    @lease.update!(payment_cycle: "annual")
    create(:invoice, lease: @lease, tenant: @tenant,
           billing_month: 11.months.ago.to_date.beginning_of_month)

    assert_no_difference "Invoice.count",
                         "annual cycle: should skip at month 11" do
      BillingService.new.generate_monthly_invoices
    end
  end

  test "TC-34c: annual lease generates invoice at 12 months since last invoice" do
    @lease.update!(payment_cycle: "annual")
    create(:invoice, lease: @lease, tenant: @tenant,
           billing_month: 12.months.ago.to_date.beginning_of_month)

    assert_difference "Invoice.count", 1,
                      "annual cycle: should generate invoice at month 12" do
      BillingService.new.generate_monthly_invoices
    end
  end

  test "quarterly lease does not generate invoice if last invoice was 1 month ago" do
    @lease.update!(payment_cycle: "quarterly")
    # Invoice generated at start of this month — only 1 month ago, not 3
    create(:invoice, lease: @lease, tenant: @tenant,
           billing_month: 1.month.ago.to_date.beginning_of_month)

    assert_no_difference "Invoice.count" do
      BillingService.new.generate_monthly_invoices
    end
  end

  test "quarterly lease generates invoice when 3 months have passed" do
    @lease.update!(payment_cycle: "quarterly")
    # Last invoice was 3 months ago — due again now
    create(:invoice, lease: @lease, tenant: @tenant,
           billing_month: 3.months.ago.to_date.beginning_of_month)

    assert_difference "Invoice.count", 1 do
      BillingService.new.generate_monthly_invoices
    end
  end

  test "generated invoice includes 10% discount line item for 3-lease tenant" do
    unit2 = create(:unit, :occupied, property: @property)
    unit3 = create(:unit, :occupied, property: @property)
    create(:lease, tenant: @tenant, unit: unit2, rent_amount: 2500)
    create(:lease, tenant: @tenant, unit: unit3, rent_amount: 2500)

    BillingService.new.generate_monthly_invoices
    invoice = Invoice.where(tenant: @tenant, lease_id: @lease.id).order(created_at: :desc).first

    discount_item = invoice.invoice_line_items.find_by(item_type: "discount")
    assert_not_nil discount_item, "discount line item should be present for 3-lease tenant"
    assert discount_item.amount.to_f < 0, "discount amount should be negative (reduction)"
    expected_discount = (@lease.rent_amount * 0.10).round(2)
    assert_in_delta expected_discount, discount_item.amount.to_f.abs, 1.0,
                    "discount should be 10% of base rent (first lease) for a 3-lease tenant"
  end

  test "monthly generate does not add duplicate invoice when period already exists" do
    # Invoice already exists for this billing month
    existing = create(:invoice, lease: @lease, tenant: @tenant,
                       billing_month: Date.today.beginning_of_month, status: "unpaid")

    assert_no_difference "Invoice.count",
                         "Re-running billing should not add a second invoice for the same period" do
      BillingService.new.generate_monthly_invoices
    end
    assert_equal "unpaid", existing.reload.status
  end

  test "generate_monthly_invoices includes discount line item for 3-lease tenant" do
    unit2 = create(:unit, :occupied, property: @property)
    unit3 = create(:unit, :occupied, property: @property)
    create(:lease, tenant: @tenant, unit: unit2, rent_amount: 2500)
    create(:lease, tenant: @tenant, unit: unit3, rent_amount: 2500)

    BillingService.new.generate_monthly_invoices
    types = Invoice.last.invoice_line_items.pluck(:item_type)
    assert_includes types, "discount"
  end

  # TC-07 / TC-08: replace existing unpaid invoice for current billing month
  test "TC-07-08: regenerate with replace_existing removes prior invoice and creates a fresh one" do
    BillingService.new.generate_monthly_invoices
    first = Invoice.find_by!(lease_id: @lease.id, billing_month: Date.today.beginning_of_month)
    first_id = first.id

    service = BillingService.new
    second = service.regenerate_invoice_for_lease(@lease.id, replace_existing: true)

    assert_not_equal first_id, second.id
    assert_nil Invoice.find_by(id: first_id)
    assert_equal Date.today.beginning_of_month, second.billing_month
  end

  # TC-09: do not replace — second invoice for same billing month and lease
  test "TC-09: regenerate without replace_existing keeps both invoices for same period" do
    BillingService.new.generate_monthly_invoices
    assert_equal 1, Invoice.where(lease_id: @lease.id, billing_month: Date.today.beginning_of_month).count

    BillingService.new.regenerate_invoice_for_lease(@lease.id, replace_existing: false)

    assert_equal 2, Invoice.where(lease_id: @lease.id, billing_month: Date.today.beginning_of_month).count
  end

  test "regenerate with replace_existing raises when invoice has payments" do
    BillingService.new.generate_monthly_invoices
    inv = Invoice.find_by!(lease_id: @lease.id, billing_month: Date.today.beginning_of_month)
    inv.update_columns(amount_paid: 100, status: "partially_paid")

    err = assert_raises(BillingService::ReplaceInvoiceBlockedError) do
      BillingService.new.regenerate_invoice_for_lease(@lease.id, replace_existing: true)
    end
    assert_match(/payments/i, err.message)
  end

end
