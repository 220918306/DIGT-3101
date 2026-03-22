require "test_helper"

class AppointmentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tenant_user = create(:user, role: "tenant")
    @tenant      = create(:tenant, user: @tenant_user)
    @tenant_token = JwtService.encode(user_id: @tenant_user.id, role: "tenant")

    @clerk_user  = create(:user, :clerk)
    @clerk_token = JwtService.encode(user_id: @clerk_user.id, role: "clerk")

    @property = create(:property)
    @unit     = create(:unit, property: @property, status: "available")
  end

  test "index returns tenant appointments" do
    create(:appointment, tenant: @tenant, unit: @unit, scheduled_time: 3.days.from_now.change(hour: 10))

    get "/api/v1/appointments", headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    assert_equal 1, JSON.parse(response.body).size
  end

  test "clerk index returns appointments for all tenants with tenant_name" do
    other = create(:tenant)
    t1 = 3.days.from_now.change(hour: 10)
    t2 = 4.days.from_now.change(hour: 11)
    create(:appointment, tenant: @tenant, unit: @unit, scheduled_time: t1, status: "pending")
    create(:appointment, tenant: other, unit: @unit, scheduled_time: t2, status: "confirmed")

    get "/api/v1/appointments", headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 2, body.size
    assert body.all? { |a| a.key?("tenant_name") }
    tenant_ids = body.map { |a| a["tenant_id"] }.uniq.sort
    assert_equal [@tenant.id, other.id].sort, tenant_ids.sort
  end

  test "clerk index filters by status param" do
    create(:appointment, tenant: @tenant, unit: @unit,
           scheduled_time: 3.days.from_now.change(hour: 10), status: "pending")
    create(:appointment, tenant: @tenant, unit: @unit,
           scheduled_time: 4.days.from_now.change(hour: 11), status: "confirmed")

    get "/api/v1/appointments", params: { status: "confirmed" },
        headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    rows = JSON.parse(response.body)
    assert_equal 1, rows.size
    assert_equal "confirmed", rows.first["status"]
  end

  test "tenant can book an appointment" do
    time = 5.days.from_now.change(hour: 14).iso8601

    post "/api/v1/appointments",
         params: { unit_id: @unit.id, scheduled_time: time },
         headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :created
    assert_equal @unit.id, JSON.parse(response.body)["unit_id"]
  end

  test "booking a conflicting slot returns 409" do
    time = 5.days.from_now.change(hour: 14)
    create(:appointment, tenant: @tenant, unit: @unit, scheduled_time: time, status: "confirmed")

    post "/api/v1/appointments",
         params: { unit_id: @unit.id, scheduled_time: time.iso8601 },
         headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :conflict
    body = JSON.parse(response.body)
    assert body.key?("next_available_slots")
  end

  test "booking with invalid datetime returns 400" do
    post "/api/v1/appointments",
         params: { unit_id: @unit.id, scheduled_time: "not-a-date" },
         headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :bad_request
  end

  test "tenant can update own appointment" do
    appt = create(:appointment, tenant: @tenant, unit: @unit, scheduled_time: 3.days.from_now.change(hour: 10))
    new_time = 6.days.from_now.change(hour: 11).iso8601

    patch "/api/v1/appointments/#{appt.id}",
          params: { scheduled_time: new_time },
          headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :ok
  end

  test "update with invalid datetime returns 400" do
    appt = create(:appointment, tenant: @tenant, unit: @unit, scheduled_time: 3.days.from_now.change(hour: 10))

    patch "/api/v1/appointments/#{appt.id}",
          params: { scheduled_time: "garbage" },
          headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :bad_request
  end

  test "tenant can cancel own appointment" do
    appt = create(:appointment, tenant: @tenant, unit: @unit,
                  scheduled_time: 3.days.from_now.change(hour: 10), status: "pending")

    delete "/api/v1/appointments/#{appt.id}",
           headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    assert_equal "cancelled", appt.reload.status
  end

  test "tenant cannot update another tenant's appointment" do
    other_tenant = create(:tenant)
    appt = create(:appointment, tenant: other_tenant, unit: @unit, scheduled_time: 3.days.from_now.change(hour: 10))

    patch "/api/v1/appointments/#{appt.id}",
          params: { scheduled_time: 7.days.from_now.change(hour: 10).iso8601 },
          headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :forbidden
  end

  test "tenant cannot cancel another tenant's appointment" do
    other_tenant = create(:tenant)
    appt = create(:appointment, tenant: other_tenant, unit: @unit, scheduled_time: 3.days.from_now.change(hour: 10))

    delete "/api/v1/appointments/#{appt.id}",
           headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :forbidden
  end

  test "clerk can reject a pending viewing" do
    appt = create(:appointment, tenant: @tenant, unit: @unit,
                  scheduled_time: 3.days.from_now.change(hour: 10), status: "pending")

    patch "/api/v1/appointments/#{appt.id}",
          params: { status: "rejected" },
          headers: { "Authorization" => "Bearer #{@clerk_token}" }, as: :json

    assert_response :ok
    assert_equal "rejected", JSON.parse(response.body)["status"]
    assert_equal "rejected", appt.reload.status
  end

  test "admin can reject a pending viewing" do
    admin_user  = create(:user, :admin)
    admin_token = JwtService.encode(user_id: admin_user.id, role: "admin")
    appt = create(:appointment, tenant: @tenant, unit: @unit,
                  scheduled_time: 3.days.from_now.change(hour: 15), status: "pending")

    patch "/api/v1/appointments/#{appt.id}",
          params: { status: "rejected" },
          headers: { "Authorization" => "Bearer #{admin_token}" }, as: :json

    assert_response :ok
    assert_equal "rejected", appt.reload.status
  end
end
