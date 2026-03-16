require "test_helper"

# TC-26: MarkOverdueInvoicesJob marks unpaid past-due invoices as overdue
class MarkOverdueInvoicesJobTest < ActiveSupport::TestCase
  def setup
    @tenant   = create(:tenant)
    @property = create(:property)
    @unit     = create(:unit, :occupied, property: @property)
    @lease    = create(:lease, tenant: @tenant, unit: @unit)
  end

  test "TC-26a: marks unpaid past-due invoices as overdue" do
    overdue_invoice = create(:invoice, lease: @lease, tenant: @tenant,
                             status: "unpaid", due_date: 5.days.ago.to_date)

    MarkOverdueInvoicesJob.new.perform

    assert_equal "overdue", overdue_invoice.reload.status
  end

  test "TC-26b: marks partially_paid past-due invoices as overdue" do
    partial_invoice = create(:invoice, lease: @lease, tenant: @tenant,
                             status: "partially_paid", due_date: 3.days.ago.to_date)

    MarkOverdueInvoicesJob.new.perform

    assert_equal "overdue", partial_invoice.reload.status
  end

  test "TC-26c: does not mark invoices with future due dates" do
    future_invoice = create(:invoice, lease: @lease, tenant: @tenant,
                            status: "unpaid", due_date: 10.days.from_now.to_date)

    MarkOverdueInvoicesJob.new.perform

    assert_equal "unpaid", future_invoice.reload.status
  end

  test "TC-26d: does not touch already-paid invoices" do
    paid_invoice = create(:invoice, lease: @lease, tenant: @tenant,
                          status: "paid", due_date: 5.days.ago.to_date)

    MarkOverdueInvoicesJob.new.perform

    assert_equal "paid", paid_invoice.reload.status
  end

  test "TC-26e: does not re-process already-overdue invoices" do
    already_overdue = create(:invoice, lease: @lease, tenant: @tenant,
                             status: "overdue", due_date: 10.days.ago.to_date)
    original_updated = already_overdue.updated_at

    travel 1.second do
      MarkOverdueInvoicesJob.new.perform
    end

    assert_equal original_updated.to_i, already_overdue.reload.updated_at.to_i
  end
end
