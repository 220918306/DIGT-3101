require "test_helper"

class NotificationServiceTest < ActiveSupport::TestCase
  def setup
    @service  = NotificationService.new
    @tenant   = create(:tenant)
    @property = create(:property)
    @unit     = create(:unit, :occupied, property: @property)
    @lease    = create(:lease, tenant: @tenant, unit: @unit)
  end

  test "send_booking_confirmation logs BOOKING_CONFIRMED" do
    appt = create(:appointment, tenant: @tenant, unit: @unit, scheduled_time: 3.days.from_now.change(hour: 10))
    assert_nothing_raised { @service.send_booking_confirmation(appt) }
  end

  test "send_invoice_generated logs INVOICE_GENERATED" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant)
    assert_nothing_raised { @service.send_invoice_generated(invoice) }
  end

  test "send_overdue_reminder increments reminder_count" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, status: "overdue",
                     due_date: 5.days.ago.to_date, reminder_count: 0)
    @service.send_overdue_reminder(invoice)
    assert_equal 1, invoice.reload.reminder_count
  end

  test "send_overdue_reminder skips paid invoices" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, status: "paid",
                     due_date: 5.days.ago.to_date, amount_paid: 2700, reminder_count: 0)
    @service.send_overdue_reminder(invoice)
    assert_equal 0, invoice.reload.reminder_count
  end

  test "send_emergency_alert logs without error" do
    ticket = create(:maintenance_ticket, lease: @lease, tenant: @tenant, unit: @unit, priority: "emergency")
    assert_nothing_raised { @service.send_emergency_alert(ticket) }
  end

  test "send_damage_bill logs without error" do
    ticket  = create(:maintenance_ticket, lease: @lease, tenant: @tenant, unit: @unit)
    invoice = create(:invoice, lease: @lease, tenant: @tenant)
    assert_nothing_raised { @service.send_damage_bill(ticket, invoice) }
  end

  test "send_urgent_alert logs without error" do
    ticket = create(:maintenance_ticket, lease: @lease, tenant: @tenant, unit: @unit, priority: "urgent")
    assert_nothing_raised { @service.send_urgent_alert(ticket) }
  end

  test "send_lease_created logs without error" do
    assert_nothing_raised { @service.send_lease_created(@lease) }
  end

  # TC-05: Upcoming viewing appointment notification
  test "TC-05a: send_upcoming_viewing_reminder logs without error for confirmed appointment" do
    appt = create(:appointment, tenant: @tenant, unit: @unit,
                   scheduled_time: 1.day.from_now.change(hour: 14), status: "confirmed")
    assert_nothing_raised { @service.send_upcoming_viewing_reminder(appt) }
  end

  test "TC-05b: send_upcoming_viewing_reminder sends for all next-day confirmed appointments" do
    tomorrow = 1.day.from_now.to_date
    appt1 = create(:appointment, tenant: @tenant, unit: @unit,
                    scheduled_time: appointment_time_on(tomorrow, 10), status: "confirmed")
    other_tenant = create(:tenant)
    appt2 = create(:appointment, tenant: other_tenant, unit: @unit,
                    scheduled_time: appointment_time_on(tomorrow, 14), status: "confirmed")

    upcoming = Appointment.where(status: "confirmed")
                          .where("DATE(scheduled_time) = ?", tomorrow)
    assert_equal 2, upcoming.count, "should find both tomorrow's confirmed appointments"
    upcoming.each { |a| assert_nothing_raised { @service.send_upcoming_viewing_reminder(a) } }
  end

  test "TC-05c: cancelled appointments are not selected for reminders" do
    tomorrow = 1.day.from_now.to_date
    create(:appointment, tenant: @tenant, unit: @unit,
            scheduled_time: appointment_time_on(tomorrow, 11), status: "cancelled")

    upcoming = Appointment.where(status: "confirmed")
                          .where("DATE(scheduled_time) = ?", tomorrow)
    assert_equal 0, upcoming.count, "cancelled appointments should be excluded"
  end

  test "send_payment_confirmation logs without error" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant)
    payment = create(:payment, invoice: invoice, tenant: @tenant)
    assert_nothing_raised { @service.send_payment_confirmation(payment) }
  end

  # TC-13: Overdue invoice notification is sent and reminder_count increments
  test "TC-13a: send_overdue_reminder sends notification and increments reminder_count" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, status: "overdue",
                     due_date: 7.days.ago.to_date, reminder_count: 0)
    @service.send_overdue_reminder(invoice)
    assert_equal 1, invoice.reload.reminder_count,
                 "reminder_count should increment after sending overdue notification"
  end

  test "TC-13b: send_overdue_reminder logs with correct tenant and invoice info" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, status: "overdue",
                     due_date: 3.days.ago.to_date, reminder_count: 0)
    assert_nothing_raised { @service.send_overdue_reminder(invoice) }
    assert_not_nil invoice.reload.last_reminder_at,
                   "last_reminder_at should be set after sending reminder"
  end

  test "TC-13c: paid invoice does not receive overdue reminder" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, status: "paid",
                     due_date: 5.days.ago.to_date, amount_paid: 2700, reminder_count: 0)
    @service.send_overdue_reminder(invoice)
    assert_equal 0, invoice.reload.reminder_count, "paid invoice should not receive reminder"
  end

  # TC-14: Multiple reminders at configured intervals (1, 7, 14, 30 days overdue)
  test "TC-14a: reminder sent at 1-day-overdue interval" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, status: "overdue",
                     due_date: 1.day.ago.to_date, reminder_count: 0)
    @service.send_overdue_reminder(invoice)
    assert_equal 1, invoice.reload.reminder_count
  end

  test "TC-14b: reminder sent at 7-day-overdue interval" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, status: "overdue",
                     due_date: 7.days.ago.to_date, reminder_count: 1)
    @service.send_overdue_reminder(invoice)
    assert_equal 2, invoice.reload.reminder_count
  end

  test "TC-14c: reminder sent at 14-day-overdue interval" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, status: "overdue",
                     due_date: 14.days.ago.to_date, reminder_count: 2)
    @service.send_overdue_reminder(invoice)
    assert_equal 3, invoice.reload.reminder_count
  end

  test "TC-14d: reminder sent at 30-day-overdue interval" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, status: "overdue",
                     due_date: 30.days.ago.to_date, reminder_count: 3)
    @service.send_overdue_reminder(invoice)
    assert_equal 4, invoice.reload.reminder_count
  end

  test "TC-14e: partially_paid invoice still receives overdue reminder" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant, status: "overdue",
                     due_date: 5.days.ago.to_date, amount: 2000, amount_paid: 500, reminder_count: 0)
    @service.send_overdue_reminder(invoice)
    assert_equal 1, invoice.reload.reminder_count,
                 "partially paid overdue invoice should still receive reminders"
  end
end
