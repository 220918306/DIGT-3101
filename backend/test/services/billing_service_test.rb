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

  # TC-07: Idempotent — does not duplicate invoices for the same period
  test "TC-07: does not generate duplicate invoices for same billing period" do
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

  # TC-11: Overpayment still marks invoice paid
  test "TC-11: overpayment still marks invoice paid" do
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

  # TC-27: 5% discount applied when tenant has 2 active leases
  test "TC-27: applies 5% discount for tenants with 2 active leases" do
    unit2 = create(:unit, :occupied, property: @property)
    create(:lease, tenant: @tenant, unit: unit2, rent_amount: 2500)

    service = BillingService.new
    assert_equal 5.0, service.discount_percentage(@tenant.id)
  end

  # TC-28: 10% discount applied when tenant has 3+ active leases
  test "TC-28: applies 10% discount for tenants with 3+ active leases" do
    unit2 = create(:unit, :occupied, property: @property)
    unit3 = create(:unit, :occupied, property: @property)
    create(:lease, tenant: @tenant, unit: unit2, rent_amount: 2500)
    create(:lease, tenant: @tenant, unit: unit3, rent_amount: 2500)

    service = BillingService.new
    assert_equal 10.0, service.discount_percentage(@tenant.id)
  end

  test "calculate_discount returns dollar amount for multi-store tenant" do
    unit2 = create(:unit, :occupied, property: @property)
    create(:lease, tenant: @tenant, unit: unit2, rent_amount: 2500)

    service = BillingService.new
    assert_equal 125.0, service.calculate_discount(@tenant.id)
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

  # TC-07: Quarterly-cycle lease does not get a new invoice when not yet due
  test "TC-07: quarterly lease does not generate invoice if last invoice was 1 month ago" do
    @lease.update!(payment_cycle: "quarterly")
    # Invoice generated at start of this month — only 1 month ago, not 3
    create(:invoice, lease: @lease, tenant: @tenant,
           billing_month: 1.month.ago.to_date.beginning_of_month)

    assert_no_difference "Invoice.count" do
      BillingService.new.generate_monthly_invoices
    end
  end

  test "TC-07b: quarterly lease DOES generate invoice when 3 months have passed" do
    @lease.update!(payment_cycle: "quarterly")
    # Last invoice was 3 months ago — due again now
    create(:invoice, lease: @lease, tenant: @tenant,
           billing_month: 3.months.ago.to_date.beginning_of_month)

    assert_difference "Invoice.count", 1 do
      BillingService.new.generate_monthly_invoices
    end
  end

  # TC-08: When tenant has 2 active leases (5% discount), the generated invoice
  # includes a discount line item and the invoice total is reduced accordingly.
  test "TC-08: invoice total reflects 5% discount for 2-lease tenant after regeneration" do
    unit2 = create(:unit, :occupied, property: @property)
    create(:lease, tenant: @tenant, unit: unit2, rent_amount: 2500)

    BillingService.new.generate_monthly_invoices
    invoice = Invoice.where(tenant: @tenant).last

    discount_item = invoice.invoice_line_items.find_by(item_type: "discount")
    assert_not_nil discount_item, "discount line item should be present for 2-lease tenant"
    assert discount_item.amount.to_f < 0, "discount amount should be negative (reduction)"
    expected_discount = (@lease.rent_amount * 0.05).round(2)
    assert_in_delta expected_discount, discount_item.amount.to_f.abs, 1.0,
                    "discount should be 5% of base rent for a 2-lease tenant"
  end

  # TC-09: When invoice already exists for the period and is NOT replaced,
  # the old invoice remains and a second run does NOT add a duplicate
  test "TC-09: existing invoice for current period is not duplicated on re-run" do
    # Invoice already exists for this billing month
    existing = create(:invoice, lease: @lease, tenant: @tenant,
                       billing_month: Date.today.beginning_of_month, status: "unpaid")

    assert_no_difference "Invoice.count",
                         "Re-running billing should not add a second invoice for the same period" do
      BillingService.new.generate_monthly_invoices
    end
    assert_equal "unpaid", existing.reload.status
  end

  test "generate_monthly_invoices includes discount line item for multi-store tenant" do
    unit2 = create(:unit, :occupied, property: @property)
    create(:lease, tenant: @tenant, unit: unit2, rent_amount: 2500)

    BillingService.new.generate_monthly_invoices
    types = Invoice.last.invoice_line_items.pluck(:item_type)
    assert_includes types, "discount"
  end

end
