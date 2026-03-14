require "test_helper"

class JwtServiceTest < ActiveSupport::TestCase
  test "encode returns a string token" do
    token = JwtService.encode(user_id: 1, role: "tenant")
    assert token.is_a?(String)
    assert_equal 3, token.split(".").size
  end

  test "decode returns the original payload" do
    token   = JwtService.encode(user_id: 42, role: "admin")
    decoded = JwtService.decode(token)

    assert_equal 42,      decoded[:user_id]
    assert_equal "admin",  decoded[:role]
  end

  test "decode raises InvalidToken for expired token" do
    payload = { user_id: 1, role: "tenant", exp: 1.hour.ago.to_i }
    secret  = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
    token   = JWT.encode(payload, secret, "HS256")

    assert_raises(ExceptionHandler::InvalidToken) { JwtService.decode(token) }
  end

  test "decode raises InvalidToken for tampered token" do
    assert_raises(ExceptionHandler::InvalidToken) { JwtService.decode("invalid.token.here") }
  end
end
