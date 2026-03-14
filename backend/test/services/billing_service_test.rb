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
end
