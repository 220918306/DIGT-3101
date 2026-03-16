require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user  = create(:user, :admin)
    @admin_token = JwtService.encode(user_id: @admin_user.id, role: "admin")

    @clerk_user  = create(:user, :clerk)
    @clerk_token = JwtService.encode(user_id: @clerk_user.id, role: "clerk")

    @tenant_user = create(:user, role: "tenant")
    @tenant      = create(:tenant, user: @tenant_user)
    @tenant_token = JwtService.encode(user_id: @tenant_user.id, role: "tenant")

    @property = create(:property)
    @unit_avail  = create(:unit, property: @property, status: "available")
    @unit_occ    = create(:unit, :occupied, property: @property)
  end

  # --- Occupancy ---

  test "admin can access occupancy report" do
    get "/api/v1/reports/occupancy", headers: { "Authorization" => "Bearer #{@admin_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert body.key?("total_units")
    assert body.key?("occupied_units")
    assert body.key?("occupancy_rate")
    assert body.key?("breakdown_by_tier")
  end

  test "clerk can access occupancy report" do
    get "/api/v1/reports/occupancy", headers: { "Authorization" => "Bearer #{@clerk_token}" }
    assert_response :ok
  end

  test "tenant cannot access occupancy report" do
    get "/api/v1/reports/occupancy", headers: { "Authorization" => "Bearer #{@tenant_token}" }
    assert_response :forbidden
  end

  # --- Revenue ---

  test "admin can access revenue report" do
    lease = create(:lease, tenant: @tenant, unit: @unit_occ)
    create(:invoice, lease: lease, tenant: @tenant, status: "paid", amount_paid: 2700)

    get "/api/v1/reports/revenue", headers: { "Authorization" => "Bearer #{@admin_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert body.key?("total_revenue")
    assert body.key?("pending_revenue")
    assert body.key?("period")
    assert body.key?("monthly_breakdown")
  end

  test "revenue report accepts date filters" do
    get "/api/v1/reports/revenue",
        params: { start_date: 60.days.ago.to_date.to_s, end_date: Date.today.to_s },
        headers: { "Authorization" => "Bearer #{@admin_token}" }

    assert_response :ok
  end

  test "revenue report includes pending revenue from partially_paid invoices" do
    lease = create(:lease, tenant: @tenant, unit: @unit_occ)
    create(:invoice, lease: lease, tenant: @tenant, status: "partially_paid",
           amount: 2000, amount_paid: 500, due_date: 5.days.from_now.to_date)

    get "/api/v1/reports/revenue", headers: { "Authorization" => "Bearer #{@admin_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert body["pending_revenue"].to_f > 0
  end

  # --- Maintenance ---

  test "admin can access maintenance report" do
    lease = create(:lease, tenant: @tenant, unit: @unit_occ)
    create(:maintenance_ticket, lease: lease, tenant: @tenant, unit: @unit_occ,
           priority: "emergency", status: "open")
    create(:maintenance_ticket, lease: lease, tenant: @tenant, unit: @unit_occ,
           priority: "routine", status: "completed", resolved_at: Time.current)

    get "/api/v1/reports/maintenance", headers: { "Authorization" => "Bearer #{@admin_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert body.key?("open")
    assert body.key?("emergency")
    assert body.key?("avg_resolution_hours")
    assert body["completed"] >= 1
  end

  test "tenant cannot access maintenance report" do
    get "/api/v1/reports/maintenance", headers: { "Authorization" => "Bearer #{@tenant_token}" }
    assert_response :forbidden
  end

  test "revenue report includes overdue and monthly breakdown" do
    lease = create(:lease, tenant: @tenant, unit: @unit_occ)
    create(:invoice, lease: lease, tenant: @tenant, status: "overdue",
           due_date: 10.days.ago.to_date, amount: 2000, amount_paid: 500)
    paid = create(:invoice, lease: lease, tenant: @tenant, status: "paid",
                  amount: 3000, amount_paid: 3000)
    paid.update_columns(updated_at: Date.today)

    get "/api/v1/reports/revenue",
        params: { start_date: 60.days.ago.to_date.to_s, end_date: Date.today.to_s },
        headers: { "Authorization" => "Bearer #{@admin_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert body["overdue_amount"].to_f > 0
    assert body["monthly_breakdown"].is_a?(Hash)
  end

  test "maintenance report with resolved tickets shows avg_resolution_hours" do
    lease  = create(:lease, tenant: @tenant, unit: @unit_occ)
    ticket = create(:maintenance_ticket, lease: lease, tenant: @tenant, unit: @unit_occ,
                    priority: "routine", status: "completed")
    ticket.update_columns(resolved_at: ticket.created_at + 2.hours)

    get "/api/v1/reports/maintenance", headers: { "Authorization" => "Bearer #{@admin_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert body["avg_resolution_hours"] > 0
  end
end
