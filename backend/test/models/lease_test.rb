require "test_helper"

class LeaseTest < ActiveSupport::TestCase
  setup do
    @property = create(:property)
    @unit     = create(:unit, :occupied, property: @property)
    @user     = create(:user)
    @tenant   = create(:tenant, user: @user)
  end

  # TC-18: Active lease with future end date returns active?=true
  test "TC-18: active lease with future end_date is active" do
    lease = create(:lease, tenant: @tenant, unit: @unit, status: "active",
                    end_date: 6.months.from_now.to_date)
    assert lease.active?, "Lease with future end date should be active"
  end

  # TC-19: Expired lease returns active?=false
  test "TC-19: expired lease is not active" do
    lease = create(:lease, tenant: @tenant, unit: @unit, status: "active",
                    end_date: 1.day.ago.to_date)
    assert_not lease.active?, "Lease with past end date should not be active"
  end

  # TC-20: calculate_discounted_rent applies discount correctly
  test "TC-20: calculate_discounted_rent reduces rent by discount_rate percent" do
    lease = create(:lease, tenant: @tenant, unit: @unit, rent_amount: 3000, discount_rate: 10)
    assert_equal 2700.0, lease.calculate_discounted_rent.to_f
  end

  # TC-21: next_invoice_due? returns true when no invoices exist
  test "TC-21: next_invoice_due returns true when no invoices exist" do
    lease = create(:lease, tenant: @tenant, unit: @unit)
    assert lease.next_invoice_due?, "Should be due if no invoices have been generated"
  end

  # TC-22: next_invoice_due? returns false when current month already invoiced
  test "TC-22: next_invoice_due returns false when current month already invoiced" do
    lease   = create(:lease, tenant: @tenant, unit: @unit)
    invoice = create(:invoice, lease: lease, tenant: @tenant,
                      billing_month: Date.today.beginning_of_month)
    assert_not lease.next_invoice_due?, "Should not be due when current month already invoiced"
  end
end
