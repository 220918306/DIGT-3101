class Api::V1::BaseController < ActionController::API
  before_action :authenticate_request!

  rescue_from ExceptionHandler::MissingToken,      with: :handle_missing_token
  rescue_from ExceptionHandler::InvalidToken,      with: :handle_invalid_token
  rescue_from ExceptionHandler::ExpiredToken,      with: :handle_expired_token
  rescue_from ExceptionHandler::UnauthorizedError, with: :handle_unauthorized
  rescue_from ActiveRecord::RecordNotFound,        with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid,         with: :handle_unprocessable
  rescue_from ActionController::ParameterMissing,  with: :handle_bad_request

  private

  def authenticate_request!
    header = request.headers["Authorization"]
    token  = header&.split(" ")&.last
    raise ExceptionHandler::MissingToken, "Missing token" unless token

    @decoded      = JwtService.decode(token)
    @current_user = User.find(@decoded[:user_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :unauthorized
  rescue ExceptionHandler::InvalidToken => e
    render json: { error: e.message }, status: :unauthorized
  end

  def authorize_roles!(*roles)
    unless roles.map(&:to_s).include?(@current_user.role.to_s)
      raise ExceptionHandler::UnauthorizedError, "Forbidden — insufficient privileges"
    end
  end

  def current_user
    @current_user
  end

  def handle_missing_token(e)
    render json: { error: e.message }, status: :unauthorized
  end

  def handle_invalid_token(e)
    render json: { error: e.message }, status: :unauthorized
  end

  def handle_not_found(e)
    render json: { error: e.message }, status: :not_found
  end

  def handle_unprocessable(e)
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def handle_expired_token(e)
    render json: { error: e.message }, status: :unauthorized
  end

  def handle_unauthorized(e)
    render json: { error: e.message }, status: :forbidden
  end

  def handle_bad_request(e)
    render json: { error: e.message }, status: :bad_request
  end
end
