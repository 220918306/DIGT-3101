require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create(:user, email: "auth_test@rems.com", password: "password123", role: "tenant")
    create(:tenant, user: @user)
  end

  # --- Login ---

  test "POST /auth/login with valid credentials returns token and user payload" do
    post "/api/v1/auth/login", params: { email: "auth_test@rems.com", password: "password123" },
                               as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert body["token"].present?, "response should include a JWT token"
    assert_equal "auth_test@rems.com", body["user"]["email"]
    assert_equal "tenant",             body["user"]["role"]
  end

  test "POST /auth/login with wrong password returns 401" do
    post "/api/v1/auth/login", params: { email: "auth_test@rems.com", password: "wrongpassword" },
                               as: :json

    assert_response :unauthorized
    assert_includes JSON.parse(response.body)["error"], "Invalid"
  end

  test "POST /auth/login with unknown email returns 401" do
    post "/api/v1/auth/login", params: { email: "nobody@rems.com", password: "password123" },
                               as: :json

    assert_response :unauthorized
  end

  # --- Register ---

  test "POST /auth/register with valid data creates user and returns token" do
    post "/api/v1/auth/register",
         params: { email: "newuser@rems.com", password: "secret123", name: "New User", phone: "416-555-9999" },
         as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert body["token"].present?, "response should include a JWT token"
    assert_equal "tenant", body["user"]["role"]
  end

  test "POST /auth/register with duplicate email returns 422" do
    post "/api/v1/auth/register",
         params: { email: "auth_test@rems.com", password: "secret123", name: "Dup User" },
         as: :json

    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].any?
  end

  test "POST /auth/register with missing password returns 422" do
    post "/api/v1/auth/register",
         params: { email: "nopass@rems.com", name: "No Pass" },
         as: :json

    assert_response :unprocessable_entity
  end

  test "POST /auth/register with duplicate email triggers handle_invalid rescue" do
    post "/api/v1/auth/register",
         params: { email: "auth_test@rems.com", password: "secret123", name: "Dup",
                   phone: "416-555-0000" },
         as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert body["errors"].any? { |e| e.downcase.include?("email") }
  end
end
