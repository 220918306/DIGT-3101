puts "Seeding database..."

# Clear existing data (in reverse dependency order)
Payment.destroy_all
InvoiceLineItem.destroy_all
Invoice.destroy_all
UtilityConsumption.destroy_all
MaintenanceTicket.destroy_all
Lease.destroy_all
Application.destroy_all
Appointment.destroy_all
Unit.destroy_all
Property.destroy_all
Tenant.destroy_all
User.destroy_all

# ── Users ──────────────────────────────────────────────────────────────────────
admin_user = User.create!(email: "admin@rems.com",   name: "Admin User",   password: "password123", role: "admin")
clerk_user = User.create!(email: "clerk@rems.com",   name: "Clerk User",   password: "password123", role: "clerk")
t1_user    = User.create!(email: "tenant1@rems.com", name: "Alice Smith",  password: "password123", role: "tenant")
t2_user    = User.create!(email: "tenant2@rems.com", name: "Bob Jones",    password: "password123", role: "tenant")
t3_user    = User.create!(email: "tenant3@rems.com", name: "Carol White",  password: "password123", role: "tenant")

tenant1 = Tenant.create!(user: t1_user, phone: "416-555-0101", company_name: "Alice's Boutique")
tenant2 = Tenant.create!(user: t2_user, phone: "416-555-0202", company_name: "Bob's Coffee")
tenant3 = Tenant.create!(user: t3_user, phone: "416-555-0303", company_name: "Carol's Wellness")

# ── Property ──────────────────────────────────────────────────────────────────
property = Property.create!(
  name:    "Oshawa Centre",
  address: "419 King St W, Oshawa, ON L1J 2K5",
  manager: "Admin User"
)

# ── Units ──────────────────────────────────────────────────────────────────────
units_data = [
  { unit_number: "A101", size: 500,  rental_rate: 2500, tier: "standard", purpose: "retail",   status: "available" },
  { unit_number: "A102", size: 750,  rental_rate: 3200, tier: "premium",  purpose: "food",     status: "available" },
  { unit_number: "B201", size: 1200, rental_rate: 5000, tier: "anchor",   purpose: "retail",   status: "occupied"  },
  { unit_number: "B202", size: 300,  rental_rate: 1800, tier: "standard", purpose: "services", status: "available" },
  { unit_number: "C301", size: 600,  rental_rate: 2800, tier: "premium",  purpose: "food",     status: "available" },
  { unit_number: "C302", size: 900,  rental_rate: 4200, tier: "anchor",   purpose: "retail",   status: "occupied"  },
  { unit_number: "D401", size: 450,  rental_rate: 2100, tier: "standard", purpose: "services", status: "available" },
]
units_data.each do |u|
  Unit.create!(property: property, **u, available: u[:status] == "available")
end

occupied_unit1 = Unit.find_by!(unit_number: "B201")
occupied_unit2 = Unit.find_by!(unit_number: "C302")
occupied_unit3 = Unit.find_by!(unit_number: "A102")
occupied_unit3.update!(status: "occupied", available: false)

# ── Active Leases ──────────────────────────────────────────────────────────────
lease1 = Lease.create!(
  tenant: tenant1, unit: occupied_unit1,
  start_date: 6.months.ago.to_date, end_date: 6.months.from_now.to_date,
  rent_amount: 5000, payment_cycle: "monthly", status: "active", discount_rate: 0
)

lease2 = Lease.create!(
  tenant: tenant2, unit: occupied_unit2,
  start_date: 3.months.ago.to_date, end_date: 9.months.from_now.to_date,
  rent_amount: 4200, payment_cycle: "monthly", status: "active", discount_rate: 0
)

# Tenant1 has 2 active leases, qualifying for 10% multi-store discount.
lease3 = Lease.create!(
  tenant: tenant1, unit: occupied_unit3,
  start_date: 1.month.ago.to_date, end_date: 11.months.from_now.to_date,
  rent_amount: 3200, payment_cycle: "monthly", status: "active", discount_rate: 10
)

# ── Invoices ──────────────────────────────────────────────────────────────────
unpaid_invoice = Invoice.create!(
  lease: lease1, tenant: tenant1,
  amount: 4700, due_date: 7.days.from_now.to_date,
  billing_month: Date.today.beginning_of_month,
  status: "unpaid"
)
InvoiceLineItem.create!(invoice: unpaid_invoice, item_type: "rent",        description: "Base Rent",     amount: 5000)
InvoiceLineItem.create!(invoice: unpaid_invoice, item_type: "electricity", description: "Electricity",   amount: 120)
InvoiceLineItem.create!(invoice: unpaid_invoice, item_type: "water",       description: "Water",         amount: 30)
InvoiceLineItem.create!(invoice: unpaid_invoice, item_type: "waste",       description: "Waste Mgmt",    amount: 50)
InvoiceLineItem.create!(invoice: unpaid_invoice, item_type: "discount",    description: "Multi-Store Discount", amount: -500)

overdue_invoice = Invoice.create!(
  lease: lease2, tenant: tenant2,
  amount: 4350, due_date: 15.days.ago.to_date,
  billing_month: 1.month.ago.beginning_of_month.to_date,
  status: "overdue"
)

# ── Maintenance Tickets ────────────────────────────────────────────────────────
MaintenanceTicket.create!(
  lease: lease1, tenant: tenant1, unit: occupied_unit1,
  priority: "urgent", status: "open",
  description: "HVAC unit making loud noise and not cooling properly"
)
MaintenanceTicket.create!(
  lease: lease2, tenant: tenant2, unit: occupied_unit2,
  priority: "routine", status: "in_progress",
  description: "Front door lock stiff and difficult to open"
)

# ── Tenant-caused Maintenance with Damage Invoice ─────────────────────────────
damage_ticket = MaintenanceTicket.create!(
  lease: lease1, tenant: tenant1, unit: occupied_unit1,
  priority: "urgent", status: "completed",
  description: "Broken storefront display caused by misuse",
  is_tenant_caused: true,
  billing_amount: 350
)

damage_invoice = Invoice.create!(
  lease: lease1, tenant: tenant1,
  amount: 350, due_date: 30.days.from_now.to_date,
  billing_month: Date.today.beginning_of_month,
  status: "unpaid"
)
InvoiceLineItem.create!(
  invoice: damage_invoice,
  item_type: "damage",
  description: "Damage repair — Ticket ##{damage_ticket.id}",
  amount: 350
)

# ── Appointment (pending viewing) ──────────────────────────────────────────────
available_unit = Unit.find_by!(unit_number: "A101")
Appointment.create!(
  unit: available_unit, tenant: tenant3,
  scheduled_time: 2.days.from_now.change(hour: 14),
  status: "confirmed"
)

# ── Application (pending review) ──────────────────────────────────────────────
Application.create!(
  tenant: tenant3, unit: available_unit,
  application_data: { business_type: "Yoga Studio", years_in_business: 3 },
  employment_info: "Self-employed, 3 years operating Carol's Wellness",
  application_date: Date.today,
  status: "pending"
)

puts "\nDatabase seeded successfully!"
puts "=" * 50
puts "Admin:   admin@rems.com  / password123"
puts "Clerk:   clerk@rems.com  / password123"
puts "Tenant1: tenant1@rems.com / password123 (active lease)"
puts "Tenant2: tenant2@rems.com / password123 (active lease)"
puts "Tenant1 now has 2 active leases (10% discount eligible)"
puts "Tenant3: tenant3@rems.com / password123 (pending application)"
puts "=" * 50
