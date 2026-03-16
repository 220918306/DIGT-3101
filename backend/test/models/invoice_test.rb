require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  def setup
    @tenant   = create(:tenant)
    @property = create(:property)
    @unit     = create(:unit, :occupied, property: @property)
    @lease    = create(:lease, tenant: @tenant, unit: @unit)
  end

  test "overdue? returns true for unpaid past-due invoice" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant,
                     status: "unpaid", due_date: 5.days.ago.to_date)
    assert invoice.overdue?
  end

  test "overdue? returns false for unpaid future invoice" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant,
                     status: "unpaid", due_date: 10.days.from_now.to_date)
    refute invoice.overdue?
  end

  test "overdue? returns false for paid invoice" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant,
                     status: "paid", due_date: 5.days.ago.to_date, amount_paid: 2700)
    refute invoice.overdue?
  end
end
