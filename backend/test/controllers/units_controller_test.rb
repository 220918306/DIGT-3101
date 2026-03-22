require "test_helper"

class UnitsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = create(:user, :admin)
    @token      = JwtService.encode(user_id: @admin_user.id, role: @admin_user.role)
    @headers    = { "Authorization" => "Bearer #{@token}" }

    @clerk_user  = create(:user, :clerk)
    @clerk_token = JwtService.encode(user_id: @clerk_user.id, role: "clerk")
    @clerk_headers = { "Authorization" => "Bearer #{@clerk_token}" }

    @tenant_user = create(:user, role: "tenant")
    @tenant_token = JwtService.encode(user_id: @tenant_user.id, role: "tenant")

    @property = create(:property)
    @available = create(:unit, property: @property, status: "available", rental_rate: 2000, tier: "standard", size: 400, purpose: "retail")
    @occupied  = create(:unit, :occupied, property: @property, rental_rate: 3500, tier: "premium", size: 900, purpose: "food")
    @large_avail = create(:unit, property: @property, status: "available", rental_rate: 2200, tier: "standard", size: 1200, purpose: "services")
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

  test "GET /units?min_size=500 filters by minimum size" do
    get "/api/v1/units", params: { min_size: 500 }, headers: @headers

    assert_response :ok
    sizes = JSON.parse(response.body).map { |u| u["size"].to_f }
    assert sizes.all? { |s| s >= 500 }
  end

  test "GET /units?max_size=500 filters by maximum size" do
    get "/api/v1/units", params: { max_size: 500 }, headers: @headers

    assert_response :ok
    sizes = JSON.parse(response.body).map { |u| u["size"].to_f }
    assert sizes.all? { |s| s <= 500 }
  end

  test "GET /units?purpose=food returns only matching purpose" do
    get "/api/v1/units", params: { purpose: "food" }, headers: @headers

    assert_response :ok
    purposes = JSON.parse(response.body).map { |u| u["purpose"] }
    assert purposes.all? { |p| p == "food" }
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

  # --- Create / Update (staff) ---

  test "admin can create a unit" do
    assert_difference -> { Unit.count }, 1 do
      post "/api/v1/units",
           params: {
             property_id: @property.id, unit_number: "X-900", size: 600,
             rental_rate: 1800, tier: "standard", purpose: "retail", status: "available", available: true
           },
           headers: @headers, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "X-900", body["unit_number"]
    assert_equal @property.name, body["property"]["name"]
  end

  test "clerk can create a unit" do
    post "/api/v1/units",
         params: {
           property_id: @property.id, unit_number: "X-901", size: 550,
           rental_rate: 1900, tier: "premium", purpose: "food", status: "available", available: true
         },
         headers: @clerk_headers, as: :json

    assert_response :created
    assert_equal "X-901", JSON.parse(response.body)["unit_number"]
  end

  test "tenant cannot create a unit" do
    post "/api/v1/units",
         params: { property_id: @property.id, unit_number: "NOPE", size: 100, rental_rate: 500 },
         headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :forbidden
  end

  test "admin can update a unit" do
    patch "/api/v1/units/#{@available.id}",
          params: { rental_rate: 2100, tier: "anchor" },
          headers: @headers, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "2100.0", body["rental_rate"].to_s
    assert_equal "anchor", body["tier"]
  end

  test "clerk can update a unit" do
    patch "/api/v1/units/#{@available.id}",
          params: { purpose: "services", available: false, status: "occupied" },
          headers: @clerk_headers, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "services", body["purpose"]
    assert_equal false, body["available"]
  end

  test "tenant cannot update a unit" do
    patch "/api/v1/units/#{@available.id}",
          params: { rental_rate: 1 },
          headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :forbidden
  end
end
