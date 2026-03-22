class LeaseFactory
  # FR-06: Create lease from approved application (Factory Pattern)
  def self.create_from_application(application, params)
    ActiveRecord::Base.transaction do
      billing      = BillingService.new
      discount_pct = billing.discount_percentage(application.tenant_id)

      lease = Lease.create!(
        tenant_id:      application.tenant_id,
        unit_id:        application.unit_id,
        application_id: application.id,
        start_date:     params[:start_date],
        end_date:       params[:end_date],
        rent_amount:    params[:rent_amount],
        payment_cycle:  params[:payment_cycle] || "monthly",
        auto_renew:     params[:auto_renew] || false,
        discount_rate:  discount_pct,
        status:         "active"
      )

      application.update!(status: "approved", approved_at: Time.current)
      application.unit.mark_as_occupied!
      NotificationService.new.send_lease_created(lease)
      lease
    end
  end
end
