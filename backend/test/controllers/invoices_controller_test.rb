require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tenant_user = create(:user, role: "tenant")
    @tenant      = create(:tenant, user: @tenant_user)
    @tenant_token = JwtService.encode(user_id: @tenant_user.id, role: "tenant")

    @clerk_user  = create(:user, :clerk)
    @clerk_token = JwtService.encode(user_id: @clerk_user.id, role: "clerk")

    @property = create(:property)
    @unit     = create(:unit, :occupied, property: @property)
    @lease    = create(:lease, tenant: @tenant, unit: @unit)
    @invoice  = create(:invoice, lease: @lease, tenant: @tenant)
  end

  test "tenant index returns own invoices" do
    get "/api/v1/invoices", headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    invoices = JSON.parse(response.body)
    assert invoices.all? { |i| i["tenant_id"] == @tenant.id }
  end

  test "clerk index returns all invoices" do
    get "/api/v1/invoices", headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    assert JSON.parse(response.body).size >= 1
  end

  test "index filters by status" do
    get "/api/v1/invoices", params: { status: "paid" },
        headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    statuses = JSON.parse(response.body).map { |i| i["status"] }
    assert statuses.all? { |s| s == "paid" }
  end

  test "show returns invoice with line items and payments" do
    @invoice.invoice_line_items.create!(item_type: "rent", description: "Base Rent", amount: 2500)
    create(:payment, invoice: @invoice, tenant: @tenant, amount: 500)

    get "/api/v1/invoices/#{@invoice.id}",
        headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert body.key?("line_items")
    assert body.key?("payments")
    assert_equal 1, body["line_items"].size
    assert_equal 1, body["payments"].size
  end

  test "tenant cannot access another tenant's invoice" do
    other_tenant = create(:tenant)
    other_invoice = create(:invoice, lease: @lease, tenant: other_tenant)

    get "/api/v1/invoices/#{other_invoice.id}",
        headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :forbidden
  end

  test "clerk can access any invoice" do
    get "/api/v1/invoices/#{@invoice.id}",
        headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
  end

  test "clerk can trigger invoice generation" do
    post "/api/v1/invoices/generate",
         headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    assert_includes JSON.parse(response.body)["message"], "Generated"
  end

  test "tenant cannot trigger invoice generation" do
    post "/api/v1/invoices/generate",
         headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :forbidden
  end
end
