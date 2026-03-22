require "test_helper"

class LeasesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tenant_user = create(:user, role: "tenant")
    @tenant      = create(:tenant, user: @tenant_user)
    @tenant_token = JwtService.encode(user_id: @tenant_user.id, role: "tenant")

    @clerk_user  = create(:user, :clerk)
    @clerk_token = JwtService.encode(user_id: @clerk_user.id, role: "clerk")

    @admin_user  = create(:user, :admin)
    @admin_token = JwtService.encode(user_id: @admin_user.id, role: "admin")

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

  # TC-21: View Unit History — clerk/admin can retrieve all past leases for a unit
  test "TC-21a: clerk can view lease history for a specific unit" do
    expired_unit = create(:unit, :occupied, property: @property)
    expired_lease = create(:lease, tenant: @tenant, unit: expired_unit,
                            status: "expired",
                            start_date: 2.years.ago.to_date,
                            end_date:   1.year.ago.to_date)

    get "/api/v1/leases", params: { unit_id: expired_unit.id },
        headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    lease_ids = JSON.parse(response.body).map { |l| l["id"] }
    assert_includes lease_ids, expired_lease.id, "history should include the expired lease"
  end

  test "TC-21b: unit history includes all statuses (active, expired, terminated)" do
    other_unit = create(:unit, :occupied, property: @property)
    active_lease     = create(:lease, tenant: @tenant, unit: other_unit, status: "active")
    expired_lease    = create(:lease, tenant: @tenant, unit: other_unit, status: "expired",
                               start_date: 2.years.ago.to_date, end_date: 1.year.ago.to_date)

    get "/api/v1/leases", params: { unit_id: other_unit.id },
        headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    ids = JSON.parse(response.body).map { |l| l["id"] }
    assert_includes ids, active_lease.id,  "should include active lease"
    assert_includes ids, expired_lease.id, "should include expired lease"
  end

  test "TC-21c: tenant cannot retrieve another unit's full history" do
    other_unit  = create(:unit, :occupied, property: @property)
    other_lease = create(:lease, tenant: create(:tenant), unit: other_unit)

    get "/api/v1/leases", params: { unit_id: other_unit.id },
        headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    ids = JSON.parse(response.body).map { |l| l["id"] }
    assert_not_includes ids, other_lease.id, "tenant should only see their own leases"
  end

  # TC-24: Lease renewal
  test "TC-24a: clerk can renew an active lease — creates new lease, expires old one" do
    expiring_lease = create(:lease, tenant: @tenant, unit: @unit, status: "active",
                             start_date: 11.months.ago.to_date,
                             end_date:   1.month.from_now.to_date)

    post "/api/v1/leases/#{expiring_lease.id}/renew",
         params: { end_date: 13.months.from_now.to_date.iso8601 },
         headers: { "Authorization" => "Bearer #{@clerk_token}" },
         as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal expiring_lease.end_date + 1, body["start_date"].to_date,
                 "new lease starts the day after old lease ends"
    assert_equal "expired", expiring_lease.reload.status, "old lease should be expired"
  end

  test "TC-24b: renewed lease inherits payment_cycle of original" do
    original = create(:lease, tenant: @tenant, unit: @unit, status: "active",
                       payment_cycle: "monthly",
                       start_date: 11.months.ago.to_date,
                       end_date:   1.month.from_now.to_date)

    post "/api/v1/leases/#{original.id}/renew",
         params: { end_date: 13.months.from_now.to_date.iso8601 },
         headers: { "Authorization" => "Bearer #{@clerk_token}" },
         as: :json

    assert_response :created
    assert_equal "monthly", JSON.parse(response.body)["payment_cycle"]
  end

  test "TC-24c: cannot renew an already expired lease" do
    expired = create(:lease, tenant: @tenant, unit: @unit, status: "expired",
                     end_date: 1.month.ago.to_date)

    post "/api/v1/leases/#{expired.id}/renew",
         params: { end_date: 11.months.from_now.to_date.iso8601 },
         headers: { "Authorization" => "Bearer #{@clerk_token}" },
         as: :json

    assert_response :unprocessable_entity
  end

  test "TC-24d: tenant cannot renew a lease" do
    active = create(:lease, tenant: @tenant, unit: @unit, status: "active",
                    end_date: 1.month.from_now.to_date)

    post "/api/v1/leases/#{active.id}/renew",
         params: { end_date: 13.months.from_now.to_date.iso8601 },
         headers: { "Authorization" => "Bearer #{@tenant_token}" },
         as: :json

    assert_response :forbidden
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

  test "clerk can view any lease by id" do
    get "/api/v1/leases/#{@lease.id}",
        headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    assert_equal @lease.id, JSON.parse(response.body)["id"]
  end

  test "lease show includes agreement_signed and agreement_status" do
    get "/api/v1/leases/#{@lease.id}",
        headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal false, body["agreement_signed"]
    assert_equal "none", body["agreement_status"]
  end

  test "lease show reflects signed agreement letter" do
    create(:letter, tenant: @tenant, lease: @lease, status: "signed", signed_at: Time.current)

    get "/api/v1/leases/#{@lease.id}",
        headers: { "Authorization" => "Bearer #{@tenant_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal true, body["agreement_signed"]
    assert_equal "signed", body["agreement_status"]
  end

  test "admin can patch lease terms" do
    new_end = @lease.end_date + 6.months

    patch "/api/v1/leases/#{@lease.id}",
          params: { end_date: new_end, auto_renew: true },
          headers: { "Authorization" => "Bearer #{@admin_token}" }, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal new_end.to_s, body["end_date"].to_s
    assert_equal true, body["auto_renew"]
  end

  test "clerk cannot patch lease" do
    patch "/api/v1/leases/#{@lease.id}",
          params: { end_date: @lease.end_date + 1.month },
          headers: { "Authorization" => "Bearer #{@clerk_token}" }, as: :json

    assert_response :forbidden
  end

  test "clerk can send lease agreement once" do
    post "/api/v1/leases/#{@lease.id}/send_agreement",
         headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_match(/sent/i, body["message"].to_s)
    assert_equal @lease.id, body["lease_id"]
    assert_equal 1, @lease.reload.letters.where(letter_type: "lease_agreement").count
  end

  test "send_agreement returns 422 when agreement already sent" do
    post "/api/v1/leases/#{@lease.id}/send_agreement",
         headers: { "Authorization" => "Bearer #{@clerk_token}" }
    assert_response :ok

    post "/api/v1/leases/#{@lease.id}/send_agreement",
         headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :unprocessable_entity
    assert_match(/awaiting signature/i, JSON.parse(response.body)["error"].to_s)
  end

  test "send_agreement returns 422 when agreement already signed" do
    create(:letter, tenant: @tenant, lease: @lease, letter_type: "lease_agreement",
                    status: "signed", signed_at: Time.current)

    post "/api/v1/leases/#{@lease.id}/send_agreement",
         headers: { "Authorization" => "Bearer #{@clerk_token}" }

    assert_response :unprocessable_entity
    assert_match(/already signed/i, JSON.parse(response.body)["error"].to_s)
  end

  test "renew without end_date computes default from lease length" do
    start_d = Date.today - 200
    end_d   = Date.today + 30
    active  = create(:lease, tenant: @tenant, unit: @unit, status: "active",
                     start_date: start_d, end_date: end_d)

    post "/api/v1/leases/#{active.id}/renew",
         params: {},
         headers: { "Authorization" => "Bearer #{@clerk_token}" },
         as: :json

    assert_response :created
    body = JSON.parse(response.body)
    expected_end = end_d + (end_d - start_d) + 1.day
    assert_equal expected_end.to_s, body["end_date"].to_s
  end

  test "renew accepts explicit rent_amount override" do
    active = create(:lease, tenant: @tenant, unit: @unit, status: "active",
                    start_date: 11.months.ago.to_date,
                    end_date: 1.month.from_now.to_date,
                    rent_amount: 2000)

    post "/api/v1/leases/#{active.id}/renew",
         params: { end_date: 13.months.from_now.to_date, rent_amount: 3200 },
         headers: { "Authorization" => "Bearer #{@clerk_token}" },
         as: :json

    assert_response :created
    assert_equal "3200.0", JSON.parse(response.body)["rent_amount"].to_s
  end
end
