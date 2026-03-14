# REMS — Real Estate Management System
## DIGT-3101 Deliverable 3 — Full Implementation

**Team 5 | Oshawa Centre Shopping Mall Tenant Management Platform**

---

## Tech Stack

| Layer       | Technology                                           |
|-------------|------------------------------------------------------|
| Backend     | Ruby 3.3.5, Rails 7.2 (API mode), PostgreSQL 14      |
| Frontend    | React 18, Vite, React Router v6, Axios, TailwindCSS 3 |
| Auth        | JWT (ruby-jwt gem) + BCrypt password hashing          |
| Background  | Sidekiq + Sidekiq-Cron (monthly invoice generation)   |
| Testing     | Minitest + FactoryBot + Shoulda Matchers + DatabaseCleaner |

---

## Roles & Access

| Role   | Capabilities |
|--------|-------------|
| **Tenant** | Search units (FR-01/02), book viewings (FR-03), apply for leases (FR-04), pay invoices (FR-07/08), submit maintenance tickets (FR-09), view utility usage (FR-11/12) |
| **Clerk**  | Review/approve/reject applications (FR-05), create leases (FR-06), generate/manage invoices (FR-07), manage maintenance queue (FR-14/17/18), bill for damage (FR-15) |
| **Admin**  | View all reports (FR-10): occupancy, revenue, maintenance metrics |

---

## Quick Start

### Prerequisites
- Ruby 3.3.5 (via rbenv)
- Node.js 18+
- PostgreSQL 14
- Redis (for Sidekiq)

### Backend Setup
```bash
cd backend
bundle install

# Database (uses rems_development / rems_test)
rails db:create db:migrate db:seed

# Start Rails API server (port 3000)
rails s -p 3000

# Start Sidekiq background worker (separate terminal)
bundle exec sidekiq
```

### Frontend Setup
```bash
cd frontend
npm install

# Start Vite dev server (port 5173)
npm run dev
```

App runs at: **http://localhost:5173**

---

## Demo Credentials

| Role   | Email                  | Password    |
|--------|------------------------|-------------|
| Admin  | admin@rems.com         | password123 |
| Clerk  | clerk@rems.com         | password123 |
| Tenant | tenant1@rems.com       | password123 |
| Tenant | tenant2@rems.com       | password123 |
| Tenant | tenant3@rems.com       | password123 |

---

## Test Suite

```bash
cd backend
rails test                         # Run all 30 tests
rails test test/models/            # Model tests only
rails test test/services/          # Service tests only
```

**Test coverage: 30 tests, 69 assertions — 0 failures**

| Test ID | Description |
|---------|-------------|
| TC-01   | Valid appointment booking |
| TC-02   | Rejects double booking of same slot |
| TC-03   | Cancelled appointments don't block slots |
| TC-04   | available_slots excludes booked hours |
| TC-05   | Rejects bookings outside business hours |
| TC-06   | Generates one invoice per active lease |
| TC-07   | Idempotent invoice generation |
| TC-08   | Invoice includes rent + utility line items |
| TC-09   | Expired leases skipped in generation |
| TC-10   | Full payment marks invoice as paid |
| TC-11   | Overpayment marks invoice paid |
| TC-12   | Partial payment with correct balance |
| TC-13   | Valid user saves with all fields |
| TC-14   | Duplicate email rejected |
| TC-15   | Invalid email format rejected |
| TC-16   | BCrypt password authentication |
| TC-17   | Role enum validates allowed values |
| TC-18   | Active lease with future end_date |
| TC-19   | Expired lease returns active?=false |
| TC-20   | calculate_discounted_rent precision |
| TC-21   | next_invoice_due? true when no invoices |
| TC-22   | next_invoice_due? false when current month invoiced |
| TC-27   | 5% discount for 2 active leases |
| TC-28   | 10% discount for 3+ active leases |
| TC-29   | Emergency tickets first in queue |
| TC-30   | Emergency auto-escalates on create |
| TC-31   | Routine tickets ordered FCFS |
| TC-32   | bill_for_damage creates damage invoice |
| TC-33   | Creates ticket with correct attributes |
| TC-34   | Completed tickets excluded from queue |

---

## API Endpoints

```
POST   /api/v1/auth/login
POST   /api/v1/auth/register

GET    /api/v1/units
GET    /api/v1/units/:id
GET    /api/v1/units/:id/available_slots

GET    /api/v1/appointments
POST   /api/v1/appointments
PATCH  /api/v1/appointments/:id
DELETE /api/v1/appointments/:id

GET    /api/v1/applications
POST   /api/v1/applications
PATCH  /api/v1/applications/:id/approve
PATCH  /api/v1/applications/:id/reject

GET    /api/v1/leases
GET    /api/v1/leases/:id
POST   /api/v1/leases

GET    /api/v1/invoices
GET    /api/v1/invoices/:id
POST   /api/v1/invoices/generate

POST   /api/v1/payments

GET    /api/v1/maintenance_tickets
POST   /api/v1/maintenance_tickets
PATCH  /api/v1/maintenance_tickets/:id
POST   /api/v1/maintenance_tickets/:id/bill_damage

GET    /api/v1/utility_consumptions
GET    /api/v1/utility_consumptions/:id

GET    /api/v1/reports/occupancy
GET    /api/v1/reports/revenue
GET    /api/v1/reports/maintenance
```

---

## Architecture & Design Patterns

| Pattern | Where Used |
|---------|-----------|
| **Factory Pattern** | `LeaseFactory.create_from_application()` — creates lease from approved application |
| **Strategy Pattern** | `MaintenanceService#handle_by_priority()` — different handling per priority level |
| **Repository-like Services** | `BillingService`, `SchedulingService`, `UtilityService` — isolate business logic from controllers |
| **Observer (after_create)** | `MaintenanceTicket` auto-escalates emergencies via callback |
| **Pessimistic Locking** | `SchedulingService#book_appointment` — `FOR UPDATE` prevents race conditions (NFR-08) |
| **FCFS Queue** | `MaintenanceService#prioritized_queue` — ordered by priority then created_at |

---

## Background Jobs (Sidekiq Cron)

| Job | Schedule | Purpose |
|-----|----------|---------|
| `GenerateInvoicesJob` | 1st of every month, midnight | Auto-generate monthly invoices for all active leases (FR-07) |
| `MarkOverdueInvoicesJob` | Daily at 8 AM | Mark past-due invoices as overdue + send reminders (FR-08) |

---

## FR Traceability

| FR ID | Feature | Implementation |
|-------|---------|----------------|
| FR-01 | Search available units | `UnitsController#index` with filters |
| FR-02 | View unit details | `UnitsController#show` |
| FR-03 | Book viewings | `AppointmentsController#create` + `SchedulingService` |
| FR-04 | Submit lease application | `ApplicationsController#create` |
| FR-05 | Approve/reject applications | `ApplicationsController#approve/reject` + `LeaseFactory` |
| FR-06 | Create lease | `LeasesController#create`, `LeaseFactory` |
| FR-07 | Generate invoices | `InvoicesController#generate` + `BillingService` + Sidekiq cron |
| FR-08 | Record payments | `PaymentsController#create` + `Invoice#mark_payment!` |
| FR-09 | Submit maintenance requests | `MaintenanceTicketsController#create` + `MaintenanceService` |
| FR-10 | System reports | `ReportsController#occupancy/revenue/maintenance` |
| FR-11 | View utility usage | `UtilityConsumptionsController#index` |
| FR-12 | Detailed invoice breakdown | Invoice line items, `InvoicesController#show` |
| FR-13 | Tenant registration | `AuthController#register` |
| FR-14 | Manage maintenance tickets | `MaintenanceTicketsController#update` |
| FR-15 | Bill tenant for damage | `MaintenanceTicketsController#bill_damage` + `MaintenanceService` |
| FR-16 | Multi-store discounts | `BillingService#DISCOUNT_TIERS` (5% at 2 leases, 10% at 3+) |
| FR-17 | Emergency escalation | `MaintenanceTicket` after_create + `MaintenanceService#escalate_emergency` |
| FR-18 | FCFS maintenance queue | `MaintenanceService#prioritized_queue` (Arel SQL priority ordering) |
