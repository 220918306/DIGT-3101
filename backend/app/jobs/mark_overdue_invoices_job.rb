class MarkOverdueInvoicesJob < ApplicationJob
  queue_as :default

  # FR-08: Runs daily at 8 AM via Sidekiq Cron
  def perform
    overdue_count = 0
    Invoice.where(status: %w[unpaid partially_paid])
           .where("due_date < ?", Date.today)
           .find_each do |invoice|
      invoice.update!(status: "overdue")
      NotificationService.new.send_overdue_reminder(invoice)
      overdue_count += 1
    end
    Rails.logger.info("MarkOverdueInvoicesJob: #{overdue_count} invoices marked overdue at #{Time.current}")
  end
end
