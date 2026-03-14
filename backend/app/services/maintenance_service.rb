class MaintenanceService
  # FR-09: Create maintenance ticket and handle by priority (Strategy Pattern)
  def create_ticket(params)
    ticket = MaintenanceTicket.create!(params)
    handle_by_priority(ticket)
    ticket
  end

  # FR-17 / FR-18: Priority-based handling strategy
  def handle_by_priority(ticket)
    case ticket.priority
    when "emergency" then escalate_emergency(ticket)
    when "urgent"    then handle_urgent(ticket)
    when "routine"   then schedule_routine(ticket)
    end
  end

  # FR-17: Emergency escalation with immediate notification
  def escalate_emergency(ticket)
    ticket.update!(status: "open") unless ticket.open?
    NotificationService.new.send_emergency_alert(ticket)
    Rails.logger.warn("EMERGENCY escalation: Ticket ##{ticket.id} at Unit #{ticket.unit_id}")
  end

  # FR-18: Prioritized queue — emergency → urgent → routine, FCFS within same priority
  def prioritized_queue
    MaintenanceTicket.where(status: %w[open in_progress])
                     .order(
                       Arel.sql("CASE priority WHEN 'emergency' THEN 0 WHEN 'urgent' THEN 1 ELSE 2 END"),
                       :created_at
                     )
  end

  # FR-15: Bill tenant for damage-caused maintenance
  def bill_for_damage(ticket_id, amount, _clerk)
    ticket = MaintenanceTicket.find(ticket_id)
    ticket.update!(is_tenant_caused: true, billing_amount: amount)

    invoice = Invoice.create!(
      lease_id:      ticket.lease_id,
      tenant_id:     ticket.tenant_id,
      billing_month: Date.today.beginning_of_month,
      due_date:      30.days.from_now,
      amount:        amount,
      status:        "unpaid"
    )
    invoice.invoice_line_items.create!(
      item_type:   "damage",
      description: "Damage repair — Ticket ##{ticket_id}",
      amount:      amount
    )
    NotificationService.new.send_damage_bill(ticket, invoice)
    invoice
  end

  private

  def handle_urgent(ticket)
    NotificationService.new.send_urgent_alert(ticket)
  end

  def schedule_routine(ticket)
    Rails.logger.info("Routine ticket ##{ticket.id} added to FCFS queue")
  end
end
