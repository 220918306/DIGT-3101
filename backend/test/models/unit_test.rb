require "test_helper"

class UnitTest < ActiveSupport::TestCase
  def setup
    @property = create(:property)
  end

  test "mark_as_occupied! changes status and available flag" do
    unit = create(:unit, property: @property, status: "available", available: true)
    unit.mark_as_occupied!
    assert_equal "occupied", unit.reload.status
    refute unit.available
  end

  test "mark_as_available! changes status and available flag" do
    unit = create(:unit, :occupied, property: @property)
    unit.mark_as_available!
    assert_equal "available", unit.reload.status
    assert unit.available
  end

  test "available_units scope returns only available units" do
    create(:unit, property: @property, status: "available", available: true)
    create(:unit, :occupied, property: @property)
    assert Unit.available_units.all? { |u| u.available && u.status == "available" }
  end

  test "filter_by_price scope returns units in range" do
    create(:unit, property: @property, rental_rate: 1000)
    create(:unit, property: @property, rental_rate: 5000)
    results = Unit.filter_by_price(900, 1500)
    assert results.all? { |u| u.rental_rate >= 900 && u.rental_rate <= 1500 }
  end
end
