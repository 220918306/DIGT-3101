require "test_helper"

class AppointmentTest < ActiveSupport::TestCase
  setup do
    @property = create(:property)
    @unit      = create(:unit, property: @property)
    @user_a    = create(:user)
    @tenant_a  = create(:tenant, user: @user_a)
    @user_b    = create(:user)
    @tenant_b  = create(:tenant, user: @user_b)
  end

  # TC-01: Valid appointment within business hours is persisted
  test "TC-01: confirms valid appointment booking" do
    appt = Appointment.create!(
      unit:           @unit,
      tenant:         @tenant_a,
      scheduled_time: 2.days.from_now.change(hour: 10),
      status:         "confirmed"
    )
    assert appt.persisted?, "Appointment should be saved to the database"
    assert_equal "confirmed", appt.status
  end

  # TC-02: Double booking the same time slot is rejected
  test "TC-02: rejects double booking of same slot" do
    time = 3.days.from_now.change(hour: 14)
    Appointment.create!(unit: @unit, tenant: @tenant_a, scheduled_time: time, status: "confirmed")

    appt_b = Appointment.new(unit: @unit, tenant: @tenant_b, scheduled_time: time)
    assert_not appt_b.valid?, "Duplicate time slot should be invalid"
    assert_includes appt_b.errors[:scheduled_time], "is already booked"
  end

  # TC-03: Cancelled appointments do not block the slot
  test "TC-03: cancelled appointment does not block the same slot" do
    time = 4.days.from_now.change(hour: 11)
    Appointment.create!(unit: @unit, tenant: @tenant_a, scheduled_time: time, status: "cancelled")

    appt_b = Appointment.new(unit: @unit, tenant: @tenant_b, scheduled_time: time, status: "confirmed")
    assert appt_b.valid?, "Slot should be available after cancellation"
  end

  test "rejected appointment does not block the same slot" do
    time = 4.days.from_now.change(hour: 12)
    Appointment.create!(unit: @unit, tenant: @tenant_a, scheduled_time: time, status: "rejected")

    appt_b = Appointment.new(unit: @unit, tenant: @tenant_b, scheduled_time: time, status: "confirmed")
    assert appt_b.valid?, "Slot should be available after clerk rejects a viewing"
  end

  # TC-04: SchedulingService#available_slots returns correct open hours
  test "TC-04: available_slots excludes booked hours" do
    date = 5.days.from_now.to_date
    Appointment.create!(
      unit: @unit, tenant: @tenant_a,
      scheduled_time: appointment_time_on(date, 10),
      status: "confirmed"
    )
    slots = SchedulingService.new.available_slots(@unit.id, date)
    assert_not_includes slots, 10, "Hour 10 should be blocked"
    assert_includes slots, 9,     "Hour 9 should be available"
    assert_includes slots, 14,    "Hour 14 should be available"
  end

  # TC-05: Appointment outside business hours is rejected
  test "TC-05: rejects bookings outside business hours" do
    appt = Appointment.new(
      unit:           @unit,
      tenant:         @tenant_a,
      scheduled_time: 2.days.from_now.change(hour: 20)
    )
    assert_not appt.valid?, "After-hours appointment should be invalid"
    assert_includes appt.errors[:scheduled_time], "must be between 9 AM and 6 PM"
  end
end
