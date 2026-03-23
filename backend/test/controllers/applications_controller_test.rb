require "test_helper"

class ApplicationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tenant_user = create(:user, role: "tenant")
    @tenant      = create(:tenant, user: @tenant_user)
    @tenant_token = JwtService.encode(user_id: @tenant_user.id, role: "tenant")

    @clerk_user  = create(:user, :clerk)
    @clerk_token = JwtService.encode(user_id: @clerk_user.id, role: "clerk")

    @admin_user  = create(:user, :admin)
    @admin_token = JwtService.encode(user_id: @admin_user.id, role: "admin")

    @property = create(:property)
    @unit     = create(:unit, property: @property, status: "available")
  end

  test "tenant index returns own applications" do
    create(:application, tenant: @tenant, unit: @unit)
    get "/api/v1/applications", headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    apps = JSON.parse(response.body)
    assert_equal 1, apps.size
    assert_equal @tenant.id, apps.first["tenant_id"]
  end

  test "clerk index returns all applications" do
    create(:application, tenant: @tenant, unit: @unit, status: "pending")
    get "/api/v1/applications", headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    assert JSON.parse(response.body).size >= 1
  end

  test "clerk index filters by status" do
    create(:application, tenant: @tenant, unit: @unit, status: "pending")
    get "/api/v1/applications", params: { status: "approved" },
        headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    assert_equal 0, JSON.parse(response.body).size
  end

  test "tenant can create an application" do
    post "/api/v1/applications",
         params: { unit_id: @unit.id, employment_info: "Employed full-time" },
         headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "pending", body["status"]
    assert_equal @unit.id, body["unit_id"]
  end

  test "clerk cannot create an application" do
    post "/api/v1/applications",
         params: { unit_id: @unit.id },
         headers: { "Authorization" => "Bearer #{@clerk_token}" }, as: :json

    assert_response :forbidden
  end

  test "admin can approve an application" do
    app = create(:application, tenant: @tenant, unit: @unit, status: "pending")

    patch "/api/v1/applications/#{app.id}/approve",
          params: { start_date: Date.today, end_date: 1.year.from_now.to_date,
                    rent_amount: 2500, payment_cycle: "monthly" },
          headers: { "Authorization" => "Bearer #{@admin_token}" }, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "approved", body["application"]["status"]
    assert_equal "active", body["lease"]["status"]
  end

  test "clerk cannot approve an application" do
    app = create(:application, tenant: @tenant, unit: @unit, status: "pending")

    patch "/api/v1/applications/#{app.id}/approve",
          params: { start_date: Date.today, end_date: 1.year.from_now.to_date,
                    rent_amount: 2500, payment_cycle: "monthly" },
          headers: { "Authorization" => "Bearer #{@clerk_token}" }, as: :json

    assert_response :forbidden
  end

  test "approving an already-processed application returns 422" do
    app = create(:application, tenant: @tenant, unit: @unit, status: "approved")

    patch "/api/v1/applications/#{app.id}/approve",
          params: { start_date: Date.today, end_date: 1.year.from_now.to_date,
                    rent_amount: 2500, payment_cycle: "monthly" },
          headers: { "Authorization" => "Bearer #{@admin_token}" }, as: :json

    assert_response :unprocessable_entity
  end

  # TC-22: Tenant cancels their own pending application
  test "TC-22a: tenant can cancel their own pending application" do
    app = create(:application, tenant: @tenant, unit: @unit, status: "pending")

    delete "/api/v1/applications/#{app.id}",
           headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "cancelled", body["status"], "application status should be 'cancelled'"
    assert_not_nil app.reload.cancelled_at, "cancelled_at timestamp should be set"
  end

  test "TC-22b: tenant cannot cancel another tenant's application" do
    other_tenant = create(:tenant)
    app = create(:application, tenant: other_tenant, unit: @unit, status: "pending")

    delete "/api/v1/applications/#{app.id}",
           headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :forbidden
    assert_equal "pending", app.reload.status
  end

  test "TC-22c: tenant cannot cancel an already-approved application" do
    app = create(:application, tenant: @tenant, unit: @unit, status: "approved")

    delete "/api/v1/applications/#{app.id}",
           headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :unprocessable_entity
    assert_equal "approved", app.reload.status
  end

  test "TC-22d: clerk cannot cancel an application via delete endpoint" do
    app = create(:application, tenant: @tenant, unit: @unit, status: "pending")

    delete "/api/v1/applications/#{app.id}",
           headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :forbidden
  end

  test "admin can reject an application" do
    app = create(:application, tenant: @tenant, unit: @unit, status: "pending")

    patch "/api/v1/applications/#{app.id}/reject",
          params: { reason: "Incomplete documents" },
          headers: { "Authorization" => "Bearer #{@admin_token}" }, as: :json

    assert_response :ok
    assert_equal "rejected", JSON.parse(response.body)["status"]
  end

  test "TC-19: reject notifies tenant via APPLICATION_REJECTED log" do
    log_io = StringIO.new
    previous = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_io)
    app = create(:application, tenant: @tenant, unit: @unit, status: "pending")

    patch "/api/v1/applications/#{app.id}/reject",
          params: { reason: "Incomplete documents" },
          headers: { "Authorization" => "Bearer #{@admin_token}" }, as: :json

    assert_response :ok
    assert_match(/APPLICATION_REJECTED/, log_io.string)
    assert_match(/Incomplete documents/, log_io.string)
  ensure
    Rails.logger = previous
  end

  test "TC-19: approve notifies tenant via APPLICATION_APPROVED and LEASE_CREATED logs" do
    log_io = StringIO.new
    previous = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_io)
    app = create(:application, tenant: @tenant, unit: @unit, status: "pending")

    patch "/api/v1/applications/#{app.id}/approve",
          params: { start_date: Date.today, end_date: 1.year.from_now.to_date,
                    rent_amount: 2500, payment_cycle: "monthly" },
          headers: { "Authorization" => "Bearer #{@admin_token}" }, as: :json

    assert_response :ok
    assert_match(/APPLICATION_APPROVED/, log_io.string)
    assert_match(/LEASE_CREATED/, log_io.string)
  ensure
    Rails.logger = previous
  end

  test "clerk cannot reject an application" do
    app = create(:application, tenant: @tenant, unit: @unit, status: "pending")

    patch "/api/v1/applications/#{app.id}/reject",
          params: { reason: "Incomplete documents" },
          headers: { "Authorization" => "Bearer #{@clerk_token}" }, as: :json

    assert_response :forbidden
  end
end
