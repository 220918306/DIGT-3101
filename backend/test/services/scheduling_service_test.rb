require "test_helper"

class SchedulingServiceTest < ActiveSupport::TestCase
  def setup
    @property = create(:property)
    @unit     = create(:unit, property: @property, status: "available")
    @tenant   = create(:tenant)
    @service  = SchedulingService.new
  end

  test "check_conflict returns false when no existing appointment" do
    time = 5.days.from_now.change(hour: 10)
    refute @service.check_conflict(@unit.id, time)
  end

  test "check_conflict returns true when slot is taken" do
    time = 5.days.from_now.change(hour: 10)
    create(:appointment, unit: @unit, tenant: @tenant, scheduled_time: time, status: "confirmed")

    assert @service.check_conflict(@unit.id, time)
  end

  test "check_conflict ignores cancelled appointments" do
    time = 5.days.from_now.change(hour: 10)
    create(:appointment, unit: @unit, tenant: @tenant, scheduled_time: time, status: "cancelled")

    refute @service.check_conflict(@unit.id, time)
  end

  test "check_conflict ignores rejected appointments" do
    time = 5.days.from_now.change(hour: 10)
    create(:appointment, unit: @unit, tenant: @tenant, scheduled_time: time, status: "rejected")

    refute @service.check_conflict(@unit.id, time)
  end

  test "book_appointment creates a pending appointment" do
    time = 5.days.from_now.change(hour: 14)
    appt = @service.book_appointment(unit_id: @unit.id, tenant_id: @tenant.id, scheduled_time: time)

    assert appt.persisted?
    assert_equal "pending", appt.status
  end

  test "book_appointment raises ConflictError on occupied unit" do
    @unit.update!(status: "occupied", available: false)

    assert_raises(ConflictError) do
      @service.book_appointment(unit_id: @unit.id, tenant_id: @tenant.id,
                                scheduled_time: 5.days.from_now.change(hour: 10))
    end
  end

  test "book_appointment raises ConflictError on double-booking" do
    time = 5.days.from_now.change(hour: 10)
    create(:appointment, unit: @unit, tenant: @tenant, scheduled_time: time, status: "confirmed")

    assert_raises(ConflictError) do
      @service.book_appointment(unit_id: @unit.id, tenant_id: @tenant.id, scheduled_time: time)
    end
  end

  # TC-02: two tenants racing for the same slot — pessimistic lock yields one success, one conflict
  test "TC-02: concurrent book_appointment calls yield one success and one conflict" do
    date     = 10.days.from_now.to_date
    time     = appointment_time_on(date, 14)
    tenant_b = create(:tenant)
    results  = []
    ready    = 0
    mutex    = Mutex.new

    worker = lambda do |tenant_id|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          mutex.synchronize { ready += 1 }
          sleep 0.01 until ready >= 2
          begin
            SchedulingService.new.book_appointment(
              unit_id: @unit.id, tenant_id: tenant_id, scheduled_time: time
            )
            mutex.synchronize { results << :success }
          rescue ConflictError
            mutex.synchronize { results << :conflict }
          end
        end
      end
    end

    t1 = worker.call(@tenant.id)
    t2 = worker.call(tenant_b.id)
    t1.join
    t2.join

    assert_equal 1, results.count { |r| r == :success }
    assert_equal 1, results.count { |r| r == :conflict }
    blocking = Appointment.where(unit_id: @unit.id, scheduled_time: time)
                          .where.not(status: Appointment::NON_BLOCKING_STATUSES)
    assert_equal 1, blocking.count
  end

  test "available_slots returns hours 9-17 minus booked" do
    date = 5.days.from_now.to_date
    create(:appointment, unit: @unit, tenant: @tenant,
           scheduled_time: appointment_time_on(date, 10), status: "confirmed")
    create(:appointment, unit: @unit, tenant: @tenant,
           scheduled_time: appointment_time_on(date, 14), status: "confirmed")

    slots = @service.available_slots(@unit.id, date)
    assert_equal [9, 11, 12, 13, 15, 16, 17], slots
  end

  test "available_slots excludes cancelled appointments" do
    date = 5.days.from_now.to_date
    create(:appointment, unit: @unit, tenant: @tenant,
           scheduled_time: appointment_time_on(date, 10), status: "cancelled")

    slots = @service.available_slots(@unit.id, date)
    assert_includes slots, 10
  end

  test "available_slots excludes rejected appointments" do
    date = 5.days.from_now.to_date
    scheduled = 5.days.from_now.change(hour: 11)
    create(:appointment, unit: @unit, tenant: @tenant,
           scheduled_time: scheduled, status: "rejected")

    slots = @service.available_slots(@unit.id, date)
    assert_includes slots, 11
  end
end
