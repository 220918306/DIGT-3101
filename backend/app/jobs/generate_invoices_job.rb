class GenerateInvoicesJob < ApplicationJob
  queue_as :default

  # FR-07: Runs on 1st of every month via Sidekiq Cron
  def perform
    count = BillingService.new.generate_monthly_invoices
    Rails.logger.info("GenerateInvoicesJob: #{count} invoices created at #{Time.current}")
  end
end
