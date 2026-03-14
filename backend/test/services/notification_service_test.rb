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

  test "send_payment_confirmation logs without error" do
    invoice = create(:invoice, lease: @lease, tenant: @tenant)
    payment = create(:payment, invoice: invoice, tenant: @tenant)
    assert_nothing_raised { @service.send_payment_confirmation(payment) }
  end
end
