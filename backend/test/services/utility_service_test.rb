require "test_helper"

# TC-24: UtilityService#get_charges returns correct breakdown
class UtilityServiceTest < ActiveSupport::TestCase
  def setup
    @tenant   = create(:tenant)
    @property = create(:property)
    @unit     = create(:unit, :occupied, property: @property)
    @lease    = create(:lease, tenant: @tenant, unit: @unit)
    @period   = Date.today.beginning_of_month
    @service  = UtilityService.new
  end

  test "TC-24a: get_charges returns a hash with electricity, water, waste, and total keys" do
    charges = @service.get_charges(@lease.id, @period)

    assert charges.key?(:electricity), "should include :electricity"
    assert charges.key?(:water),       "should include :water"
    assert charges.key?(:waste),       "should include :waste"
    assert charges.key?(:total),       "should include :total"
  end

  test "TC-24b: waste charge is always the flat fee of 50.0" do
    charges = @service.get_charges(@lease.id, @period)
    assert_equal 50.0, charges[:waste]
  end

  test "TC-24c: total equals electricity + water + waste" do
    charges = @service.get_charges(@lease.id, @period)
    expected_total = (charges[:electricity] + charges[:water] + charges[:waste]).round(2)
    assert_equal expected_total, charges[:total]
  end

  test "TC-24d: get_charges is idempotent — calling twice returns the same total" do
    first  = @service.get_charges(@lease.id, @period)
    second = @service.get_charges(@lease.id, @period)
    assert_equal first[:total], second[:total]
  end

  test "TC-24e: electricity charge is non-negative" do
    charges = @service.get_charges(@lease.id, @period)
    assert charges[:electricity] >= 0
  end
end
