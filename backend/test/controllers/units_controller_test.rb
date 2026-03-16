require "test_helper"

class UnitsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = create(:user, :admin)
    @token      = JwtService.encode(user_id: @admin_user.id, role: @admin_user.role)
    @headers    = { "Authorization" => "Bearer #{@token}" }

    @property = create(:property)
    @available = create(:unit, property: @property, status: "available", rental_rate: 2000, tier: "standard")
    @occupied  = create(:unit, :occupied, property: @property, rental_rate: 3500, tier: "premium")
  end

  # --- Index ---

  test "GET /units returns all units" do
    get "/api/v1/units", headers: @headers

    assert_response :ok
    ids = JSON.parse(response.body).map { |u| u["id"] }
    assert_includes ids, @available.id
    assert_includes ids, @occupied.id
  end

  test "GET /units?available_only=true returns only available units" do
    get "/api/v1/units", params: { available_only: "true" }, headers: @headers

    assert_response :ok
    statuses = JSON.parse(response.body).map { |u| u["status"] }
    assert statuses.all? { |s| s == "available" }, "all units should be available"
  end

  test "GET /units?min_price=3000 filters by minimum rental rate" do
    get "/api/v1/units", params: { min_price: 3000 }, headers: @headers

    assert_response :ok
    rates = JSON.parse(response.body).map { |u| u["rental_rate"].to_f }
    assert rates.all? { |r| r >= 3000 }, "all rates should be >= 3000"
  end

  test "GET /units?max_price=2500 filters by maximum rental rate" do
    get "/api/v1/units", params: { max_price: 2500 }, headers: @headers

    assert_response :ok
    rates = JSON.parse(response.body).map { |u| u["rental_rate"].to_f }
    assert rates.all? { |r| r <= 2500 }, "all rates should be <= 2500"
  end

  test "GET /units?tier=premium returns only premium units" do
    get "/api/v1/units", params: { tier: "premium" }, headers: @headers

    assert_response :ok
    tiers = JSON.parse(response.body).map { |u| u["tier"] }
    assert tiers.all? { |t| t == "premium" }
  end

  # --- Show ---

  test "GET /units/:id returns unit with property details" do
    get "/api/v1/units/#{@available.id}", headers: @headers

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal @available.id,          body["id"]
    assert_equal @property.name,         body["property"]["name"]
  end

  test "GET /units/:id for missing unit returns 404" do
    get "/api/v1/units/9999999", headers: @headers
    assert_response :not_found
  end

  # --- Available Slots ---

  test "GET /units/:id/available_slots returns slots for a valid date" do
    date = 3.days.from_now.to_date.to_s
    get "/api/v1/units/#{@available.id}/available_slots", params: { date: date }, headers: @headers

    assert_response :ok
    body = JSON.parse(response.body)
    assert body.key?("available_slots"), "response should include available_slots"
    assert_equal date, body["date"]
  end

  test "GET /units/:id/available_slots with bad date returns 400" do
    get "/api/v1/units/#{@available.id}/available_slots", params: { date: "not-a-date" }, headers: @headers
    assert_response :bad_request
  end

  # --- Auth ---

  test "GET /units without token returns 401" do
    get "/api/v1/units"
    assert_response :unauthorized
  end

  test "request with expired token returns 401" do
    payload = { user_id: @admin_user.id, role: "admin", exp: 1.hour.ago.to_i }
    secret  = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
    expired_token = JWT.encode(payload, secret, "HS256")

    get "/api/v1/units", headers: { "Authorization" => "Bearer #{expired_token}" }
    assert_response :unauthorized
  end

  test "request with tampered token returns 401" do
    get "/api/v1/units", headers: { "Authorization" => "Bearer invalid.token.here" }
    assert_response :unauthorized
  end

  test "GET /units/:id for deleted user returns 401" do
    token = JwtService.encode(user_id: 9999999, role: "admin")
    get "/api/v1/units/#{@available.id}", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :unauthorized
  end

  test "GET /units/:id for nonexistent unit triggers handle_not_found" do
    get "/api/v1/units/9999999", headers: @headers
    assert_response :not_found
    assert JSON.parse(response.body).key?("error")
  end

  test "GET /units/:id/available_slots triggers handle_bad_request" do
    get "/api/v1/units/#{@available.id}/available_slots",
        params: { date: "not-a-date" }, headers: @headers
    assert_response :bad_request
  end
end
