require "test_helper"

class UtilityConsumptionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tenant_user = create(:user, role: "tenant")
    @tenant      = create(:tenant, user: @tenant_user)
    @tenant_token = JwtService.encode(user_id: @tenant_user.id, role: "tenant")

    @clerk_user  = create(:user, :clerk)
    @clerk_token = JwtService.encode(user_id: @clerk_user.id, role: "clerk")

    @property = create(:property)
    @unit     = create(:unit, :occupied, property: @property)
    @lease    = create(:lease, tenant: @tenant, unit: @unit)

    @consumption = UtilityConsumption.create!(
      lease_id: @lease.id,
      billing_period: Date.today.beginning_of_month,
      electricity_usage: 1000, electricity_charge: 120.0,
      water_usage: 3000, water_charge: 9.0,
      waste_charge: 50.0
    )
  end

  test "tenant index returns own utility consumptions" do
    get "/api/v1/utility_consumptions",
        headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    data = JSON.parse(response.body)
    assert data.all? { |c| c["lease_id"] == @lease.id }
  end

  test "clerk index returns all utility consumptions" do
    get "/api/v1/utility_consumptions",
        headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    assert JSON.parse(response.body).size >= 1
  end

  test "show returns a specific consumption record" do
    get "/api/v1/utility_consumptions/#{@consumption.id}",
        headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal @consumption.id, body["id"]
    assert body.key?("total_charge")
    assert_equal 179.0, body["total_charge"].to_f
  end
end
