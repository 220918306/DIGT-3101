class NotificationService
  # FR-03: Booking confirmation
  def send_booking_confirmation(appointment)
    log("BOOKING_CONFIRMED", appointment.tenant_id,
        "Appointment ##{appointment.id} confirmed for Unit #{appointment.unit_id} at #{appointment.scheduled_time}")
  end

  # FR-07: Invoice generated notification
  def send_invoice_generated(invoice)
    log("INVOICE_GENERATED", invoice.tenant_id,
        "Invoice ##{invoice.id} — $#{invoice.amount} due #{invoice.due_date}")
  end

  # FR-08: Overdue reminder (NFR-05)
  def send_overdue_reminder(invoice)
    return if invoice.paid?

    invoice.increment!(:reminder_count)
    invoice.update!(last_reminder_at: Time.current)
    days_overdue = (Date.today - invoice.due_date).to_i
    log("OVERDUE_REMINDER", invoice.tenant_id,
        "Invoice ##{invoice.id} overdue by #{days_overdue} days — balance $#{invoice.remaining_balance}")
  end

  # FR-09 / FR-17: Emergency maintenance alert
  def send_emergency_alert(ticket)
    log("EMERGENCY_MAINTENANCE", ticket.tenant_id,
        "EMERGENCY ticket ##{ticket.id} — Unit #{ticket.unit_id}: #{ticket.description}")
  end

  # FR-15: Damage billing notification
  def send_damage_bill(ticket, invoice)
    log("DAMAGE_BILL", ticket.tenant_id,
        "Damage charge $#{invoice.amount} — Ticket ##{ticket.id}")
  end

  # FR-14: Urgent maintenance alert
  def send_urgent_alert(ticket)
    log("URGENT_MAINTENANCE", ticket.tenant_id,
        "Urgent ticket ##{ticket.id} — Unit #{ticket.unit_id}")
  end

  # FR-06: Lease created notification
  def send_lease_created(lease)
    log("LEASE_CREATED", lease.tenant_id,
        "Lease ##{lease.id} created — Unit #{lease.unit_id} from #{lease.start_date} to #{lease.end_date}")
  end

  # FR-03: Upcoming viewing appointment reminder (TC-05)
  def send_upcoming_viewing_reminder(appointment)
    log("UPCOMING_VIEWING_REMINDER", appointment.tenant_id,
        "Reminder: Appointment ##{appointment.id} for Unit #{appointment.unit_id} " \
        "is tomorrow at #{appointment.scheduled_time.strftime('%H:%M')}")
  end

  # FR-08: Payment confirmation
  def send_payment_confirmation(payment)
    log("PAYMENT_CONFIRMED", payment.tenant_id,
        "Payment ##{payment.id} of $#{payment.amount} confirmed via #{payment.payment_method}")
  end

  # FR-05: Tenant notified when application is approved or rejected (TC-19)
  def notify_application_decision(application:, approved:)
    if approved
      log("APPLICATION_APPROVED", application.tenant_id,
          "Application ##{application.id} for Unit #{application.unit_id} was approved.")
    else
      reason = application.rejection_reason.presence
      log("APPLICATION_REJECTED", application.tenant_id,
          "Application ##{application.id} was rejected#{reason ? ": #{reason}" : ""}.")
    end
  end

  private

  def log(event, user_id, message)
    Rails.logger.info("[NOTIFICATION] #{event} | user=#{user_id} | #{message}")
  end
end
