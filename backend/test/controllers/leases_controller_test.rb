require "test_helper"

class LeasesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tenant_user = create(:user, role: "tenant")
    @tenant      = create(:tenant, user: @tenant_user)
    @tenant_token = JwtService.encode(user_id: @tenant_user.id, role: "tenant")

    @clerk_user  = create(:user, :clerk)
    @clerk_token = JwtService.encode(user_id: @clerk_user.id, role: "clerk")

    @property = create(:property)
    @unit     = create(:unit, :occupied, property: @property)
    @lease    = create(:lease, tenant: @tenant, unit: @unit)
  end

  test "tenant index returns own leases" do
    get "/api/v1/leases", headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    leases = JSON.parse(response.body)
    assert leases.all? { |l| l["tenant_id"] == @tenant.id }
  end

  test "clerk index returns all leases" do
    get "/api/v1/leases", headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    assert JSON.parse(response.body).size >= 1
  end

  test "clerk index filters by status" do
    get "/api/v1/leases", params: { status: "expired" },
        headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    assert JSON.parse(response.body).all? { |l| l["status"] == "expired" }
  end

  test "tenant can view own lease" do
    get "/api/v1/leases/#{@lease.id}",
        headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal @lease.id, body["id"]
    assert body.key?("unit_number")
  end

  test "tenant cannot view another tenant's lease" do
    other_tenant = create(:tenant)
    other_unit   = create(:unit, :occupied, property: @property)
    other_lease  = create(:lease, tenant: other_tenant, unit: other_unit)

    get "/api/v1/leases/#{other_lease.id}",
        headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :forbidden
  end

  test "clerk can create a lease" do
    new_unit = create(:unit, property: @property, status: "available")

    post "/api/v1/leases",
         params: { tenant_id: @tenant.id, unit_id: new_unit.id,
                   start_date: Date.today, end_date: 1.year.from_now.to_date,
                   rent_amount: 3000, payment_cycle: "monthly" },
         headers: { "Authorization" => "Bearer #{@clerk_token}" }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "active", body["status"]
    assert_equal "occupied", new_unit.reload.status
  end

  test "tenant cannot create a lease" do
    new_unit = create(:unit, property: @property, status: "available")

    post "/api/v1/leases",
         params: { tenant_id: @tenant.id, unit_id: new_unit.id,
                   start_date: Date.today, end_date: 1.year.from_now.to_date,
                   rent_amount: 3000, payment_cycle: "monthly" },
         headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :forbidden
  end
end
