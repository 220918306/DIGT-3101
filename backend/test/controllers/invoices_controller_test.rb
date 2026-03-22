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

  test "clerk can patch utility line items on a regular invoice" do
    @invoice.invoice_line_items.create!(item_type: "rent", description: "Base Rent", amount: 2500)
    @invoice.invoice_line_items.create!(item_type: "electricity", description: "Electricity", amount: 10)
    @invoice.invoice_line_items.create!(item_type: "water", description: "Water", amount: 20)
    @invoice.invoice_line_items.create!(item_type: "waste", description: "Waste Management", amount: 30)
    @invoice.update_column(:amount, 2560)

    patch "/api/v1/invoices/#{@invoice.id}/utilities",
          params: { electricity: 100, water: 50, waste: 25 },
          headers: { "Authorization" => "Bearer #{@clerk_token}" },
          as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    # rent 2500 + electricity 100 + water 50 + waste 25
    assert_equal "2675.0", body["amount"].to_s
    assert_equal 100.0, body["utility_electricity"]
    @invoice.reload
    assert_equal 2675, @invoice.amount.to_f
  end

  test "clerk cannot patch utilities on a damage invoice" do
    damage_inv = create(:invoice, lease: @lease, tenant: @tenant)
    damage_inv.invoice_line_items.create!(
      item_type: "damage",
      description: "Damage repair",
      amount: 400
    )
    damage_inv.update_column(:amount, 400)

    patch "/api/v1/invoices/#{damage_inv.id}/utilities",
          params: { electricity: 1, water: 1, waste: 1 },
          headers: { "Authorization" => "Bearer #{@clerk_token}" },
          as: :json

    assert_response :unprocessable_entity
  end

  test "tenant cannot patch invoice utilities" do
    @invoice.invoice_line_items.create!(item_type: "rent", description: "Base Rent", amount: 2500)

    patch "/api/v1/invoices/#{@invoice.id}/utilities",
          params: { electricity: 1, water: 1, waste: 1 },
          headers: { "Authorization" => "Bearer #{@tenant_token}" },
          as: :json

    assert_response :forbidden
  end

  test "utilities patch returns 422 when new total is less than amount already paid" do
    @invoice.invoice_line_items.create!(item_type: "rent", description: "Base Rent", amount: 1000)
    @invoice.invoice_line_items.create!(item_type: "electricity", description: "Electricity", amount: 500)
    @invoice.invoice_line_items.create!(item_type: "water", description: "Water", amount: 500)
    @invoice.invoice_line_items.create!(item_type: "waste", description: "Waste Management", amount: 500)
    @invoice.update_columns(amount: 2500, amount_paid: 2400, status: "partially_paid")

    patch "/api/v1/invoices/#{@invoice.id}/utilities",
          params: { electricity: 0, water: 0, waste: 0 },
          headers: { "Authorization" => "Bearer #{@clerk_token}" },
          as: :json

    assert_response :unprocessable_entity
    errors = JSON.parse(response.body)["errors"]
    assert_kind_of Array, errors
    assert errors.any? { |m| m.include?("cannot be less than amount already paid") },
           "expected paid-total guard message, got: #{errors.inspect}"
    @invoice.reload
    assert_equal 2500, @invoice.amount.to_f
  end

  test "utilities patch returns 422 when a utility amount is negative" do
    @invoice.invoice_line_items.create!(item_type: "rent", description: "Base Rent", amount: 2500)
    @invoice.invoice_line_items.create!(item_type: "electricity", description: "Electricity", amount: 10)
    @invoice.invoice_line_items.create!(item_type: "water", description: "Water", amount: 10)
    @invoice.invoice_line_items.create!(item_type: "waste", description: "Waste Management", amount: 10)
    @invoice.update_column(:amount, 2530)

    patch "/api/v1/invoices/#{@invoice.id}/utilities",
          params: { electricity: -5, water: 0, waste: 0 },
          headers: { "Authorization" => "Bearer #{@clerk_token}" },
          as: :json

    assert_response :unprocessable_entity
    errors = JSON.parse(response.body)["errors"]
    assert errors.any? { |m| m.include?("Amounts must be zero or greater") },
           "expected non-negative amount message, got: #{errors.inspect}"
  end
end
