require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tenant_user = create(:user, role: "tenant")
    @tenant      = create(:tenant, user: @tenant_user)
    @tenant_token = JwtService.encode(user_id: @tenant_user.id, role: "tenant")

    @clerk_user  = create(:user, :clerk)
    @clerk_token = JwtService.encode(user_id: @clerk_user.id, role: "clerk")

    @property = create(:property)
    @unit     = create(:unit, :occupied, property: @property)
    @lease    = create(:lease, tenant: @tenant, unit: @unit)
    @invoice  = create(:invoice, lease: @lease, tenant: @tenant, amount: 2700, amount_paid: 0, status: "unpaid")
  end

  test "tenant can make a full payment" do
    post "/api/v1/payments",
         params: { invoice_id: @invoice.id, amount: 2700, payment_method: "online" },
         headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "paid", body["invoice_status"]
    assert_equal 0.0, body["remaining_balance"].to_f
  end

  test "tenant can make a partial payment" do
    post "/api/v1/payments",
         params: { invoice_id: @invoice.id, amount: 1000 },
         headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "partially_paid", body["invoice_status"]
    assert_equal 1700.0, body["remaining_balance"].to_f
  end

  test "payment with zero amount returns 422" do
    post "/api/v1/payments",
         params: { invoice_id: @invoice.id, amount: 0 },
         headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :unprocessable_entity
  end

  test "payment on fully-paid invoice returns 422" do
    @invoice.update!(status: "paid", amount_paid: 2700)

    post "/api/v1/payments",
         params: { invoice_id: @invoice.id, amount: 100 },
         headers: { "Authorization" => "Bearer #{@tenant_token}" }, as: :json

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "already fully paid"
  end

  test "clerk can also record a payment" do
    post "/api/v1/payments",
         params: { invoice_id: @invoice.id, amount: 500 },
         headers: { "Authorization" => "Bearer #{@clerk_token}" }, as: :json

    assert_response :created
  end
end
