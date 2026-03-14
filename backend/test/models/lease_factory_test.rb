require "test_helper"

# TC-25: LeaseFactory.create_from_application transaction test
class LeaseFactoryTest < ActiveSupport::TestCase
  def setup
    @tenant   = create(:tenant)
    @property = create(:property)
    @unit     = create(:unit, property: @property, status: "available", available: true)
    @application = create(:application, tenant: @tenant, unit: @unit, status: "pending")
  end

  def lease_params
    { rent_amount: 2500, payment_cycle: "monthly",
      start_date: Date.today, end_date: 1.year.from_now.to_date }
  end

  test "TC-25a: create_from_application returns a persisted lease" do
    lease = LeaseFactory.create_from_application(@application, lease_params)
    assert lease.persisted?, "lease should be saved to the database"
  end

  test "TC-25b: lease has correct tenant and unit" do
    lease = LeaseFactory.create_from_application(@application, lease_params)
    assert_equal @tenant.id, lease.tenant_id
    assert_equal @unit.id,   lease.unit_id
  end

  test "TC-25c: unit status is set to occupied after approval" do
    LeaseFactory.create_from_application(@application, lease_params)
    assert_equal "occupied", @unit.reload.status
  end

  test "TC-25d: application status is set to approved after approval" do
    LeaseFactory.create_from_application(@application, lease_params)
    assert_equal "approved", @application.reload.status
  end

  test "TC-25e: entire operation rolls back if lease creation fails" do
    bad_params = lease_params.merge(rent_amount: nil)
    assert_raises(ActiveRecord::RecordInvalid) do
      LeaseFactory.create_from_application(@application, bad_params)
    end
    assert_equal "pending",   @application.reload.status
    assert_equal "available", @unit.reload.status
  end
end
