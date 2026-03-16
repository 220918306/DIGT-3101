if defined?(Sidekiq) && Sidekiq.respond_to?(:configure_server)
  Sidekiq.configure_server do |config|
    config.on(:startup) do
      Sidekiq::Cron::Job.load_from_hash(
        "generate_monthly_invoices" => {
          "cron"  => "0 0 1 * *",
          "class" => "GenerateInvoicesJob",
          "queue" => "default"
        },
        "mark_overdue_invoices" => {
          "cron"  => "0 8 * * *",
          "class" => "MarkOverdueInvoicesJob",
          "queue" => "default"
        }
      )
    end
  end
end
