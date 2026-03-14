class JwtService
  EXPIRY = 24.hours

  def self.encode(payload)
    payload[:exp] = EXPIRY.from_now.to_i
    secret = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
    JWT.encode(payload, secret, "HS256")
  end

  def self.decode(token)
    secret = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
    decoded = JWT.decode(token, secret, true, { algorithm: "HS256" })
    HashWithIndifferentAccess.new(decoded[0])
  rescue JWT::ExpiredSignature
    raise ExceptionHandler::InvalidToken, "Token has expired"
  rescue JWT::DecodeError => e
    raise ExceptionHandler::InvalidToken, e.message
  end
end
