class Api::V1::PaymentsController < Api::V1::BaseController
  # POST /api/v1/payments — FR-08: Record payment (full or partial)
  def create
    invoice = Invoice.find(params[:invoice_id])
    amount  = params[:amount].to_f

    if amount <= 0
      return render json: { error: "Payment amount must be greater than zero" }, status: :unprocessable_entity
    end

    if invoice.paid?
      return render json: { error: "Invoice is already fully paid" }, status: :unprocessable_entity
    end

    if amount > invoice.remaining_balance
      return render json: { error: "Payment amount cannot exceed remaining balance" }, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      tenant_id = current_user.tenant? ? current_user.tenant.id : invoice.tenant_id

      payment = Payment.create!(
        invoice_id:     invoice.id,
        tenant_id:      tenant_id,
        amount:         amount,
        payment_method: params[:payment_method] || "online",
        transaction_id: SecureRandom.hex(10),
        status:         "approved",
        processed:      true
      )
      invoice.mark_payment!(amount)
      NotificationService.new.send_payment_confirmation(payment)

      render json: {
        payment:           { id: payment.id, amount: payment.amount,
                             transaction_id: payment.transaction_id,
                             payment_method: payment.payment_method },
        invoice_status:    invoice.reload.status,
        remaining_balance: invoice.remaining_balance
      }, status: :created
    end
  end
end
