require "test_helper"

class LettersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tenant_user = create(:user, role: "tenant")
    @tenant      = create(:tenant, user: @tenant_user)
    @tenant_token = JwtService.encode(user_id: @tenant_user.id, role: "tenant")

    @other_tenant = create(:tenant)

    @clerk_user  = create(:user, :clerk)
    @clerk_token = JwtService.encode(user_id: @clerk_user.id, role: "clerk")

    @property = create(:property)
    @unit     = create(:unit, :occupied, property: @property)
    @lease    = create(:lease, tenant: @tenant, unit: @unit)
    @letter   = create(:letter, tenant: @tenant, lease: @lease, status: "sent")
  end

  test "tenant index returns only own letters" do
    create(:letter, tenant: @other_tenant, lease: create(:lease, tenant: @other_tenant, unit: create(:unit, :occupied, property: @property)))

    get "/api/v1/letters", headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    ids = JSON.parse(response.body).map { |l| l["id"] }
    assert_includes ids, @letter.id
    assert_equal ids.size, 1
  end

  test "clerk index returns letters for all tenants" do
    other_lease = create(:lease, tenant: @other_tenant, unit: create(:unit, :occupied, property: @property))
    other_letter = create(:letter, tenant: @other_tenant, lease: other_lease)

    get "/api/v1/letters", headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    ids = JSON.parse(response.body).map { |l| l["id"] }
    assert_includes ids, @letter.id
    assert_includes ids, other_letter.id
  end

  test "letter json includes lease summary" do
    get "/api/v1/letters", headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    row = JSON.parse(response.body).find { |l| l["id"] == @letter.id }
    assert_equal @lease.unit_id, row["lease"]["unit_id"]
    assert_equal @lease.start_date.to_s, row["lease"]["start_date"].to_s
    assert_equal @lease.rent_amount.to_s, row["lease"]["rent_amount"].to_s
  end

  test "tenant can sign own sent letter" do
    post "/api/v1/letters/#{@letter.id}/sign",
         headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "signed", body["status"]
    assert_not_nil body["signed_at"]
    assert_equal "signed", @letter.reload.status
  end

  test "tenant cannot sign another tenant letter" do
    other_lease = create(:lease, tenant: @other_tenant, unit: create(:unit, :occupied, property: @property))
    other_letter = create(:letter, tenant: @other_tenant, lease: other_lease)

    post "/api/v1/letters/#{other_letter.id}/sign",
         headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :forbidden
  end

  test "sign already signed letter returns 422" do
    @letter.update!(status: "signed", signed_at: Time.current)

    post "/api/v1/letters/#{@letter.id}/sign",
         headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :unprocessable_entity
    assert_match(/already signed/i, JSON.parse(response.body)["error"].to_s)
  end

  test "clerk cannot sign letters" do
    post "/api/v1/letters/#{@letter.id}/sign",
         headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :forbidden
  end
end
