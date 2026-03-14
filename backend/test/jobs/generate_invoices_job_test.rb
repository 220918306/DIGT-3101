require "test_helper"

class GenerateInvoicesJobTest < ActiveSupport::TestCase
  def setup
    @tenant   = create(:tenant)
    @property = create(:property)
    @unit     = create(:unit, :occupied, property: @property)
    @lease    = create(:lease, tenant: @tenant, unit: @unit)
  end

  test "perform generates invoices for active leases" do
    assert_difference "Invoice.count" do
      GenerateInvoicesJob.new.perform
    end
  end

  test "perform is idempotent — running twice does not duplicate" do
    GenerateInvoicesJob.new.perform
    assert_no_difference "Invoice.count" do
      GenerateInvoicesJob.new.perform
    end
  end
end
