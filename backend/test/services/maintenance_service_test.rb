require "test_helper"

class MaintenanceServiceTest < ActiveSupport::TestCase
  setup do
    @property  = create(:property)
    @unit      = create(:unit, :occupied, property: @property)
    @user      = create(:user)
    @tenant    = create(:tenant, user: @user)
    @lease     = create(:lease, tenant: @tenant, unit: @unit)
    @service   = MaintenanceService.new
  end

  # TC-29: Emergency tickets appear first in the prioritized queue
  test "TC-29: emergency tickets appear first in queue" do
    routine   = create(:maintenance_ticket, lease: @lease, tenant: @tenant, unit: @unit,
                        priority: "routine",   status: "open", description: "Routine task")
    urgent    = create(:maintenance_ticket, lease: @lease, tenant: @tenant, unit: @unit,
                        priority: "urgent",    status: "open", description: "Urgent task")
    emergency = create(:maintenance_ticket, lease: @lease, tenant: @tenant, unit: @unit,
                        priority: "emergency", status: "open", description: "Emergency!")

    queue = @service.prioritized_queue
    assert_equal emergency.id, queue.first.id,  "Emergency should be first"
    assert_equal urgent.id,    queue.second.id, "Urgent should be second"
    assert_equal routine.id,   queue.last.id,   "Routine should be last"
  end

  # TC-30: Emergency ticket triggers NotificationService on create
  test "TC-30: emergency ticket auto-escalates on create" do
    notification_called = false

    mock_notifier = Object.new
    mock_notifier.define_singleton_method(:send_emergency_alert) do |_ticket|
      notification_called = true
    end

    original_new = NotificationService.method(:new)
    NotificationService.define_singleton_method(:new) { mock_notifier }

    begin
      MaintenanceTicket.create!(
        priority:    "emergency",
        status:      "open",
        lease:       @lease,
        tenant:      @tenant,
        unit:        @unit,
        description: "Major flood in unit"
      )
    ensure
      NotificationService.define_singleton_method(:new) { original_new.call }
    end

    assert notification_called, "Emergency notification should have been sent"
  end

  # TC-31: Routine tickets are ordered FCFS within same priority
  test "TC-31: routine tickets ordered FCFS within same priority" do
    ticket_a = create(:maintenance_ticket, lease: @lease, tenant: @tenant, unit: @unit,
                       priority: "routine", status: "open", description: "First routine",
                       created_at: 2.hours.ago)
    ticket_b = create(:maintenance_ticket, lease: @lease, tenant: @tenant, unit: @unit,
                       priority: "routine", status: "open", description: "Second routine",
                       created_at: 1.hour.ago)

    queue = @service.prioritized_queue
    routine_ids = queue.where(priority: "routine").pluck(:id)
    assert_equal ticket_a.id, routine_ids.first, "Earlier routine ticket should come first (FCFS)"
  end

  # TC-32: bill_for_damage creates invoice and marks ticket as tenant-caused
  test "TC-32: bill_for_damage creates damage invoice and marks ticket" do
    ticket = create(:maintenance_ticket, lease: @lease, tenant: @tenant, unit: @unit,
                     priority: "urgent", status: "in_progress", description: "Broken door")

    admin_user = create(:user, :admin)

    assert_difference "Invoice.count", 1 do
      invoice = @service.bill_for_damage(ticket.id, 500.0, admin_user)
      assert_equal 500.0, invoice.amount
      assert_equal "unpaid", invoice.status
    end

    ticket.reload
    assert ticket.is_tenant_caused, "Ticket should be marked as tenant-caused"
    assert_equal 500.0, ticket.billing_amount
  end

  # TC-33: create_ticket assigns correct priority and calls handler
  test "TC-33: creates ticket with correct attributes" do
    ticket = @service.create_ticket(
      lease_id:    @lease.id,
      tenant_id:   @tenant.id,
      unit_id:     @unit.id,
      priority:    "urgent",
      description: "Water leak under sink",
      status:      "open"
    )
    assert ticket.persisted?
    assert_equal "urgent",  ticket.priority
    assert_equal "open",    ticket.status
  end

  # TC-34: Completed tickets are excluded from active queue
  test "TC-34: completed tickets are excluded from prioritized queue" do
    create(:maintenance_ticket, lease: @lease, tenant: @tenant, unit: @unit,
            priority: "routine", status: "completed", description: "Done")
    create(:maintenance_ticket, lease: @lease, tenant: @tenant, unit: @unit,
            priority: "urgent", status: "cancelled", description: "Cancelled")

    queue = @service.prioritized_queue
    statuses = queue.pluck(:status).uniq
    assert_not_includes statuses, "completed"
    assert_not_includes statuses, "cancelled"
  end
end
