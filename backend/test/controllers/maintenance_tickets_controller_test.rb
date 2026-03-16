require "test_helper"

# TC-23: Multi-lease tenant maintenance ticket submission + authorization tests
class MaintenanceTicketsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tenant_user = create(:user, role: "tenant")
    @tenant      = create(:tenant, user: @tenant_user)
    @tenant_token = JwtService.encode(user_id: @tenant_user.id, role: "tenant")

    @clerk_user  = create(:user, :clerk)
    @clerk_token = JwtService.encode(user_id: @clerk_user.id, role: "clerk")

    @admin_user  = create(:user, :admin)
    @admin_token = JwtService.encode(user_id: @admin_user.id, role: "admin")

    @property = create(:property)
    @unit1    = create(:unit, :occupied, property: @property)
    @unit2    = create(:unit, :occupied, property: @property)
    @lease1   = create(:lease, tenant: @tenant, unit: @unit1)
    @lease2   = create(:lease, tenant: @tenant, unit: @unit2)
  end

  # --- Index ---

  test "tenant index returns own tickets ordered by created_at desc" do
    create(:maintenance_ticket, lease: @lease1, tenant: @tenant, unit: @unit1, description: "First")
    create(:maintenance_ticket, lease: @lease2, tenant: @tenant, unit: @unit2, description: "Second")

    get "/api/v1/maintenance_tickets",
        headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    tickets = JSON.parse(response.body)
    assert_equal 2, tickets.size
    assert tickets.all? { |t| t["tenant_id"] == @tenant.id }
  end

  test "clerk index returns prioritized queue" do
    create(:maintenance_ticket, lease: @lease1, tenant: @tenant, unit: @unit1,
           priority: "routine", status: "open", description: "Routine")
    create(:maintenance_ticket, lease: @lease1, tenant: @tenant, unit: @unit1,
           priority: "emergency", status: "open", description: "Emergency!")

    get "/api/v1/maintenance_tickets",
        headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    tickets = JSON.parse(response.body)
    assert_equal "emergency", tickets.first["priority"]
  end

  # --- TC-23: Multi-lease tenant can specify lease_id ---

  test "TC-23a: tenant with single active lease can create ticket without lease_id" do
    @lease2.update!(status: "expired")

    post "/api/v1/maintenance_tickets",
         params: { description: "Broken door", priority: "routine" },
         headers: { "Authorization" => "Bearer #{@tenant_token}" },
         as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal @lease1.id, body["lease_id"]
  end

  test "TC-23b: tenant with multiple active leases gets 422 without lease_id" do
    post "/api/v1/maintenance_tickets",
         params: { description: "Broken door", priority: "routine" },
         headers: { "Authorization" => "Bearer #{@tenant_token}" },
         as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["error"], "Multiple active leases"
    assert body["lease_ids"].is_a?(Array)
  end

  test "TC-23c: tenant with multiple active leases can create ticket with lease_id" do
    post "/api/v1/maintenance_tickets",
         params: { description: "Leaking pipe", priority: "urgent", lease_id: @lease2.id },
         headers: { "Authorization" => "Bearer #{@tenant_token}" },
         as: :json

    assert_response :created
    assert_equal @lease2.id, JSON.parse(response.body)["lease_id"]
  end

  test "TC-23d: tenant cannot use a lease_id that belongs to another tenant" do
    other_tenant = create(:tenant)
    other_unit   = create(:unit, :occupied, property: @property)
    other_lease  = create(:lease, tenant: other_tenant, unit: other_unit)

    post "/api/v1/maintenance_tickets",
         params: { description: "Fake request", lease_id: other_lease.id },
         headers: { "Authorization" => "Bearer #{@tenant_token}" },
         as: :json

    assert_response :not_found
  end

  # --- Authorization ---

  test "clerk cannot create maintenance tickets" do
    post "/api/v1/maintenance_tickets",
         params: { description: "Clerk attempt", lease_id: @lease1.id },
         headers: { "Authorization" => "Bearer #{@clerk_token}" },
         as: :json

    assert_response :forbidden
  end

  test "tenant cannot update ticket status" do
    ticket = create(:maintenance_ticket, lease: @lease1, tenant: @tenant, unit: @unit1)

    patch "/api/v1/maintenance_tickets/#{ticket.id}",
          params: { status: "completed" },
          headers: { "Authorization" => "Bearer #{@tenant_token}" },
          as: :json

    assert_response :forbidden
  end

  test "clerk can update ticket status" do
    ticket = create(:maintenance_ticket, lease: @lease1, tenant: @tenant, unit: @unit1)

    patch "/api/v1/maintenance_tickets/#{ticket.id}",
          params: { status: "in_progress" },
          headers: { "Authorization" => "Bearer #{@clerk_token}" },
          as: :json

    assert_response :ok
    assert_equal "in_progress", JSON.parse(response.body)["status"]
  end

  # TC-23 (report): Maintenance ticket status lifecycle — open → in_progress → completed
  test "TC-23-report-a: clerk sets ticket from open to in_progress" do
    ticket = create(:maintenance_ticket, lease: @lease1, tenant: @tenant, unit: @unit1,
                    status: "open", priority: "routine", description: "Dripping tap")

    patch "/api/v1/maintenance_tickets/#{ticket.id}",
          params: { status: "in_progress" },
          headers: { "Authorization" => "Bearer #{@clerk_token}" },
          as: :json

    assert_response :ok
    assert_equal "in_progress", ticket.reload.status
  end

  test "TC-23-report-b: clerk sets ticket from in_progress to completed" do
    ticket = create(:maintenance_ticket, lease: @lease1, tenant: @tenant, unit: @unit1,
                    status: "in_progress", priority: "routine", description: "Dripping tap")

    patch "/api/v1/maintenance_tickets/#{ticket.id}",
          params: { status: "completed" },
          headers: { "Authorization" => "Bearer #{@clerk_token}" },
          as: :json

    assert_response :ok
    assert_equal "completed", ticket.reload.status
  end

  test "TC-23-report-c: admin can update ticket status to any valid value" do
    ticket = create(:maintenance_ticket, lease: @lease1, tenant: @tenant, unit: @unit1,
                    status: "open", priority: "urgent")

    patch "/api/v1/maintenance_tickets/#{ticket.id}",
          params: { status: "completed" },
          headers: { "Authorization" => "Bearer #{@admin_token}" },
          as: :json

    assert_response :ok
    assert_equal "completed", ticket.reload.status
  end

  # --- bill_damage ---

  test "admin can bill a tenant for damage" do
    ticket = create(:maintenance_ticket, lease: @lease1, tenant: @tenant, unit: @unit1)

    post "/api/v1/maintenance_tickets/#{ticket.id}/bill_damage",
         params: { amount: 500.0 },
         headers: { "Authorization" => "Bearer #{@admin_token}" },
         as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal 500.0, body["amount"].to_f
  end

  test "bill_damage with zero amount returns 422" do
    ticket = create(:maintenance_ticket, lease: @lease1, tenant: @tenant, unit: @unit1)

    post "/api/v1/maintenance_tickets/#{ticket.id}/bill_damage",
         params: { amount: 0 },
         headers: { "Authorization" => "Bearer #{@admin_token}" },
         as: :json

    assert_response :unprocessable_entity
  end

  test "tenant cannot call bill_damage" do
    ticket = create(:maintenance_ticket, lease: @lease1, tenant: @tenant, unit: @unit1)

    post "/api/v1/maintenance_tickets/#{ticket.id}/bill_damage",
         params: { amount: 200.0 },
         headers: { "Authorization" => "Bearer #{@tenant_token}" },
         as: :json

    assert_response :forbidden
  end
end
