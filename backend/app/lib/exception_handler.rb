module ExceptionHandler
  class AuthenticationError < StandardError; end
  class MissingToken < StandardError; end
  class InvalidToken < StandardError; end
  class ExpiredToken < StandardError; end
  class UnauthorizedError < StandardError; end
end
