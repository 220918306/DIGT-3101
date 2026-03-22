class Api::V1::LettersController < Api::V1::BaseController
  # GET /api/v1/letters
  def index
    letters = if current_user.tenant?
      Letter.includes(:lease).where(tenant_id: current_user.tenant.id)
    else
      Letter.includes(:lease, tenant: :user)
    end
    letters = letters.order(created_at: :desc)
    render json: letters.map { |l| letter_json(l) }
  end

  # POST /api/v1/letters/:id/sign
  def sign
    authorize_roles!("tenant")
    letter = Letter.find(params[:id])
    if letter.tenant_id != current_user.tenant&.id
      return render json: { error: "Forbidden" }, status: :forbidden
    end
    return render json: { error: "Letter already signed" }, status: :unprocessable_entity if letter.signed?

    letter.update!(status: "signed", signed_at: Time.current)
    render json: letter_json(letter)
  end

  private

  def letter_json(l)
    {
      id: l.id,
      lease_id: l.lease_id,
      tenant_id: l.tenant_id,
      letter_type: l.letter_type,
      status: l.status,
      subject: l.subject,
      body: l.body,
      sent_at: l.sent_at,
      signed_at: l.signed_at,
      lease: {
        unit_id: l.lease&.unit_id,
        start_date: l.lease&.start_date,
        end_date: l.lease&.end_date,
        rent_amount: l.lease&.rent_amount,
        payment_cycle: l.lease&.payment_cycle
      }
    }
  end
end
