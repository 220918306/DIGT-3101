class Api::V1::AuthController < ActionController::API
  rescue_from ActiveRecord::RecordInvalid, with: :handle_invalid

  # POST /api/v1/auth/login
  def login
    user = User.find_by(email: params[:email]&.downcase)
    if user&.authenticate(params[:password])
      token = JwtService.encode(user_id: user.id, role: user.role)
      render json: { token: token, user: user_payload(user) }
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  # POST /api/v1/auth/register — creates tenant account (FR-13)
  def register
    user = User.new(user_params.merge(role: "tenant"))
    if user.save
      Tenant.create!(user: user, phone: params[:phone], company_name: params[:company_name])
      token = JwtService.encode(user_id: user.id, role: user.role)
      render json: { token: token, user: user_payload(user) }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.permit(:email, :password, :name)
  end

  def user_payload(user)
    { id: user.id, email: user.email, name: user.name, role: user.role }
  end

  def handle_invalid(e)
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end
end
