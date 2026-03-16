require "benchmark"

namespace :perf do
  desc "PT-01 — benchmark recording a partial payment for a single invoice"
  task record_payment: :environment do
    invoice = Invoice.joins(:lease).where(status: "unpaid").first

    unless invoice
      puts "No unpaid invoices found; creating a sample invoice for PT-01."
      lease = Lease.first || FactoryBot.create(:lease)
      invoice = FactoryBot.create(:invoice, lease:, tenant: lease.tenant, amount: 2000, amount_paid: 0, status: "unpaid")
    end

    elapsed = Benchmark.realtime do
      invoice.mark_payment!(invoice.amount / 2)
    end

    puts "PT-01 record_payment elapsed: #{(elapsed * 1000).round(1)} ms"
  end

  desc "Helper task to seed ~1000 active leases for invoice generation perf tests"
  task seed_thousand_leases: :environment do
    target = 1000
    existing = Lease.count
    remaining = [target - existing, 0].max

    puts "Existing leases: #{existing}. Seeding #{remaining} more to reach #{target}..."

    remaining.times do |i|
      tenant  = FactoryBot.create(:tenant)
      unit    = FactoryBot.create(:unit, :occupied)
      FactoryBot.create(:lease, tenant:, unit:, status: "active", rent_amount: 2500)
      puts "Created lease #{i + 1}/#{remaining}" if (i + 1) % 100 == 0
    end

    puts "Seeding complete. Total leases: #{Lease.count}"
  end

  desc "PT-03 — measure invoice generation time for up to 1000 active leases"
  task invoices: :environment do
    active_leases = Lease.where(status: "active").count
    puts "Active leases: #{active_leases}. Consider running `rails perf:seed_thousand_leases` first." if active_leases < 1000

    service = BillingService.new
    elapsed = Benchmark.realtime do
      service.generate_monthly_invoices
    end

    ms = (elapsed * 1000).round(1)
    puts "PT-03 invoice generation elapsed: #{ms} ms"
    puts "PT-03 RESULT: #{ms < 30_000 ? 'PASS' : 'FAIL'} (threshold: < 30000 ms)"
  end
end

