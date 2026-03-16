# Real Estate Management System (REMS)

A full-stack property management platform built with **Ruby on Rails 7.2** (API) and **React 19** (Vite). 


---

## Table of Contents

1. [Tech Stack](#tech-stack)
2. [Prerequisites](#prerequisites)
3. [Project Structure](#project-structure)
4. [Backend Setup](#backend-setup)
5. [Frontend Setup](#frontend-setup)
6. [Running the App](#running-the-app)
7. [Demo Credentials](#demo-credentials)
8. [API Reference](#api-reference)
9. [Running the Test Suite](#running-the-test-suite)
10. [Background Jobs](#background-jobs)
11. [Architecture Notes](#architecture-notes)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Ruby 3.3.5, Rails 7.2 (API mode) |
| Database | PostgreSQL 14+ |
| Auth | JWT (ruby-jwt) + BCrypt |
| Background Jobs | Sidekiq + Sidekiq-Cron + Redis |
| Frontend | React 19, Vite, React Router v7 |
| Styling | TailwindCSS 3 |
| HTTP Client | Axios |
| Testing | Minitest, FactoryBot, Shoulda Matchers, DatabaseCleaner |

---

## Prerequisites

Make sure the following are installed before you start:

```bash
ruby --version        # 3.3.5
rails --version       # 7.2.x
node --version        # 18+
npm --version         # 9+
psql --version        # 14+
redis-server --version  # 7+
```

Install Ruby 3.3.5 via rbenv if needed:

```bash
rbenv install 3.3.5
rbenv local 3.3.5
```

---

## Project Structure

```
DIGT-3101/
├── backend/                       # Rails 7.2 API
│   ├── app/
│   │   ├── controllers/api/v1/    # All API controllers
│   │   ├── models/                # 13 domain models
│   │   ├── services/              # Business logic services
│   │   ├── factories/             # LeaseFactory (Factory Pattern)
│   │   └── jobs/                  # Sidekiq background jobs
│   ├── config/
│   │   ├── routes.rb
│   │   └── initializers/
│   ├── db/
│   │   ├── migrate/               # 13 migrations
│   │   └── seeds.rb               # Demo data
│   └── test/                      # Minitest suite (TC-01 to TC-34)
│
└── frontend/                      # React 19 + Vite
    └── src/
        ├── api/                   # Axios modules per resource
        ├── context/               # AuthContext (JWT storage)
        ├── components/            # Navbar, StatusBadge, LoadingSpinner
        └── pages/
            ├── tenant/            # Dashboard, UnitSearch, MyInvoices, Maintenance
            ├── clerk/             # Dashboard, Applications, MaintenanceQueue, Invoices
            └── admin/             # Dashboard, Reports
```

---

## Backend Setup

### 1. Navigate to the backend folder

```bash
cd DIGT-3101/backend
```

### 2. Install Ruby gems

```bash
bundle install
```

### 3. Configure the database

The app reads database credentials from environment variables. Export them in your shell:

```bash
export DB_USERNAME=postgres
export DB_PASSWORD=yourpassword
export DB_HOST=localhost
```

Or open `config/database.yml` and replace the `ENV[...]` values with your local credentials directly.

### 4. Create and migrate the database

```bash
rails db:create
rails db:migrate
```

### 5. Seed demo data

```bash
rails db:seed
```

This creates 5 users, 2 properties, 6 units, 3 leases, invoices, maintenance tickets, and appointments so the app is immediately usable.

Expected output:

```
Admin:   admin@rems.com   / password123
Clerk:   clerk@rems.com   / password123
Tenant1: tenant1@rems.com / password123  (active lease)
Tenant2: tenant2@rems.com / password123  (active lease)
Tenant3: tenant3@rems.com / password123  (pending application)
```

### 6. Start the Rails server

```bash
rails server -p 3000
```

The API is now running at `http://localhost:3000/api/v1`.

---

## Frontend Setup

### 1. Navigate to the frontend folder

```bash
cd DIGT-3101/frontend
```

### 2. Install npm packages

```bash
npm install
```

### 3. Check the environment file

A `.env` file should already exist. If not, create one:

```
VITE_API_URL=http://localhost:3000
```

### 4. Start the dev server

```bash
npm run dev
```

The app is now running at `http://localhost:5173`.

> Vite proxies all `/api` requests to `http://localhost:3000`, so both servers can run simultaneously without CORS issues.

---

## Running the App

Open **two terminal windows** and run both servers at the same time:

**Terminal 1 — Backend:**

```bash
cd DIGT-3101/backend
rails server -p 3000
```

**Terminal 2 — Frontend:**

```bash
cd DIGT-3101/frontend
npm run dev
```

Then open `http://localhost:5173` in your browser.

---

## Demo Credentials

| Role | Email | Password | What you can do |
|---|---|---|---|
| **Admin** | admin@rems.com | password123 | View all reports, manage system-wide data |
| **Clerk** | clerk@rems.com | password123 | Approve applications, manage maintenance queue, generate invoices |
| **Tenant 1** | tenant1@rems.com | password123 | Active lease — view invoices, pay, submit maintenance |
| **Tenant 2** | tenant2@rems.com | password123 | Active lease — same as Tenant 1 |
| **Tenant 3** | tenant3@rems.com | password123 | Pending application — search units, book viewings |

---

## API Reference

All endpoints are prefixed with `/api/v1`.

Protected endpoints require this header:

```
Authorization: Bearer <your_jwt_token>
```

You get the token from the login or register response.

### Authentication (public)

| Method | Endpoint | Body | Returns |
|---|---|---|---|
| POST | `/auth/login` | `{ email, password }` | `{ token, user }` |
| POST | `/auth/register` | `{ name, email, password, phone }` | `{ token, user }` |

### Units

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/units` | Any | List units. Filter with `?status=available&min_price=1000&max_price=2000` |
| GET | `/units/:id` | Any | Unit detail |
| GET | `/units/:id/available_slots` | Any | List open 1-hour viewing slots |

### Appointments

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/appointments` | Any | List your appointments |
| POST | `/appointments` | Tenant | Book a viewing — uses pessimistic lock to prevent double-booking |
| PATCH | `/appointments/:id` | Any | Reschedule or update |
| DELETE | `/appointments/:id` | Any | Cancel |

### Applications

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/applications` | Any | Tenant sees own; Clerk and Admin see all pending |
| POST | `/applications` | Tenant | Submit a rental application |
| PATCH | `/applications/:id/approve` | Clerk/Admin | Approve — automatically creates a lease and marks unit occupied |
| PATCH | `/applications/:id/reject` | Clerk/Admin | Reject application |

### Leases

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/leases` | Any | List leases (tenant sees own) |
| GET | `/leases/:id` | Any | Lease detail |
| POST | `/leases` | Clerk/Admin | Create a lease manually |

### Invoices and Payments

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/invoices` | Any | Tenant sees own; Clerk/Admin see all |
| GET | `/invoices/:id` | Any | Invoice with full line items and payment history |
| POST | `/invoices/generate` | Clerk/Admin | Trigger monthly invoice generation for all active leases |
| POST | `/payments` | Tenant | Record a payment — handles full and partial automatically |

### Maintenance Tickets

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/maintenance_tickets` | Any | Tenant sees own; Clerk gets FCFS priority-sorted queue |
| POST | `/maintenance_tickets` | Tenant | Submit a new ticket |
| PATCH | `/maintenance_tickets/:id` | Clerk/Admin | Update ticket status |
| POST | `/maintenance_tickets/:id/bill_damage` | Admin | Charge tenant for damage repair |

### Utility Consumptions

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/utility_consumptions` | Clerk/Admin | List all utility records |
| GET | `/utility_consumptions/:id` | Clerk/Admin | Detail for one record |

### Reports (Clerk and Admin only)

| Method | Endpoint | Description |
|---|---|---|
| GET | `/reports/occupancy` | Per-property occupancy percentages |
| GET | `/reports/revenue` | Monthly revenue breakdown |
| GET | `/reports/maintenance` | Ticket volume and average resolution time |

---

## Running the Test Suite

```bash
cd DIGT-3101/backend
rails test
```

Run only model tests:

```bash
rails test test/models/
```

Run only service tests:

```bash
rails test test/services/
```

Run a single file:

```bash
rails test test/services/billing_service_test.rb
```

### What is tested (163 tests, 304 assertions, 98.84% coverage)

| Test File | Tests | What is covered |
|---|---|---|
| `models/user_test.rb` | 5 | Validations, BCrypt, role enum (TC-13–17) |
| `models/appointment_test.rb` | 7 | Double-booking, out-of-hours, scopes (TC-01–05) |
| `models/lease_test.rb` | 9 | Payment cycles (monthly/quarterly/biannual/annual), status (TC-18–22) |
| `models/lease_factory_test.rb` | 5 | Factory Pattern: transaction, rollback (TC-25) |
| `models/invoice_test.rb` | 3 | `overdue?` method, remaining balance |
| `models/unit_test.rb` | 4 | `mark_as_occupied!`, `mark_as_available!`, scopes |
| `services/billing_service_test.rb` | 10 | Idempotency, discount tiers, line items (TC-06–12, TC-27–28) |
| `services/maintenance_service_test.rb` | 6 | Strategy dispatch, FCFS queue, damage billing (TC-29–34) |
| `services/scheduling_service_test.rb` | 8 | Pessimistic lock, conflict detection, available slots |
| `services/utility_service_test.rb` | 5 | Charge breakdown, idempotency (TC-24) |
| `services/jwt_service_test.rb` | 4 | Encode/decode, expired token, tampered token |
| `services/notification_service_test.rb` | 9 | All notification methods, overdue skip logic |
| `controllers/auth_controller_test.rb` | 7 | Login (valid/invalid), register (valid/dup/missing) |
| `controllers/units_controller_test.rb` | 14 | Filters, show, slots, 401/404 edge cases |
| `controllers/appointments_controller_test.rb` | 9 | Book, conflict 409, update, cancel, cross-tenant protection |
| `controllers/applications_controller_test.rb` | 8 | Create, approve, reject, status filter, role guards |
| `controllers/leases_controller_test.rb` | 7 | Index, show, create, cross-tenant protection |
| `controllers/invoices_controller_test.rb` | 8 | Index, show with line items, generate, access control |
| `controllers/payments_controller_test.rb` | 5 | Full/partial payment, zero amount, already paid |
| `controllers/reports_controller_test.rb` | 9 | Occupancy, revenue, maintenance, date filters, role guards |
| `controllers/utility_consumptions_controller_test.rb` | 3 | Index (tenant/clerk), show |
| `controllers/maintenance_tickets_controller_test.rb` | 13 | Multi-lease (TC-23), auth, bill_damage, priority queue |
| `jobs/generate_invoices_job_test.rb` | 2 | Perform, idempotency |
| `jobs/mark_overdue_invoices_job_test.rb` | 5 | Overdue marking, skip paid/future (TC-26) |

Expected result:

```
163 runs, 304 assertions, 0 failures, 0 errors, 0 skips
```

---

## Background Jobs

The app uses Sidekiq for scheduled background tasks. To enable them:

### 1. Start Redis

```bash
redis-server
```

### 2. Start Sidekiq

```bash
cd DIGT-3101/backend
bundle exec sidekiq
```

### Scheduled jobs

| Job | Runs | What it does |
|---|---|---|
| `GenerateInvoicesJob` | 1st of every month at 00:05 | Creates monthly invoices for all active leases. Safe to retry — skips leases already billed this period |
| `MarkOverdueInvoicesJob` | Daily at 01:00 | Marks any unpaid past-due invoices as `overdue` |

> Without Sidekiq running the app still works fully. You can trigger invoice generation manually via the clerk dashboard or by calling `POST /api/v1/invoices/generate`.

---

## Architecture Notes

| Pattern | Location | Purpose |
|---|---|---|
| **Factory Pattern** | `app/factories/lease_factory.rb` | `LeaseFactory.create_from_application` wraps the entire lease creation in one transaction — application approval, lease creation, unit status change, and notification all succeed or all roll back together |
| **Strategy Pattern** | `app/services/maintenance_service.rb` | `handle_by_priority` dispatches to the right handler based on ticket category. Adding a new priority tier requires one new method and one hash entry — no if/case chains |
| **Observer Pattern** | `app/models/maintenance_ticket.rb` | `after_create` callback auto-escalates emergency tickets to `urgent` status without any controller involvement |
| **Pessimistic Locking** | `app/services/scheduling_service.rb` | `SELECT FOR UPDATE` on appointment slots ensures two tenants racing to book the same slot cannot both succeed |
| **FCFS Queue** | `app/services/maintenance_service.rb` | Tickets are ordered by priority tier then `created_at` — within the same priority, earlier submissions are handled first |
| **Idempotent Billing** | `app/services/billing_service.rb` | `generate_monthly_invoices` checks for an existing invoice before creating — the Sidekiq cron job can safely retry without duplicating charges |

---

## User Story Traceability

| US ID | Description | Status | Notes |
|---|---|---|---|
| FR-01 | Search and filter available units | Implemented | Filters: status, price range, size, tier, purpose |
| FR-02 | View unit detail | Implemented | Returns unit + property info |
| FR-03 | Book a unit viewing (appointment) | Implemented | Pessimistic lock prevents double-booking |
| FR-04 | Submit a rental application | Implemented | Tenant-only; tied to a specific unit |
| FR-05 | Approve or reject application | Implemented | Clerk/Admin; triggers LeaseFactory on approval |
| FR-06 | Create lease from approved application | Implemented | Factory Pattern — atomic transaction |
| FR-07 | Generate monthly invoices | Implemented | Idempotent; safe to retry via Sidekiq Cron |
| FR-08 | View invoice with line items | Implemented | Base rent, utilities, damage fees as separate line items |
| FR-09 | Submit maintenance request | Implemented | Tenants with multiple leases must supply `lease_id` |
| FR-10 | Record a payment | Implemented | Handles full and partial payments automatically |
| FR-11 | Calculate utility charges | Implemented | Simulated consumption; rates defined in `UtilityService` |
| FR-12 | View maintenance ticket queue | Implemented | FCFS within priority tier (emergency → urgent → routine) |
| FR-13 | Tenant self-registration | Implemented | Creates User + Tenant in one request |
| FR-14 | Update maintenance ticket status | Implemented | Clerk/Admin only |
| FR-15 | Bill tenant for damage | Implemented | Creates invoice + line item; Admin only |
| FR-16 | Occupancy report | Implemented | Per-property occupancy percentages |
| FR-17 | Revenue report | Implemented | Monthly revenue breakdown |
| FR-18 | Maintenance report | Implemented | Ticket volume and resolution stats |
| NFR-01 | JWT stateless authentication | Implemented | HS256, 24-hour expiry, role-based access control |
| NFR-08 | Concurrent booking safety | Implemented | `SELECT FOR UPDATE` in `SchedulingService` |
| NFR-09 | FCFS maintenance queue | Implemented | Priority tier + `created_at` ordering |
| NFR-10 | Email notifications | **Partially Implemented** | `NotificationService` logs all events via `Rails.logger`. Real SMTP/email delivery is deferred to a future iteration (see Known Scope Deferrals below) |

---

## Known Scope Deferrals

| Item | Reason | Future Work |
|---|---|---|
| **Email delivery (NotificationService)** | `NotificationService` is intentionally a logging stub for this iteration. All notification events (booking confirmations, invoice reminders, emergency alerts, damage bills) are recorded in the Rails log. Wiring real SMTP delivery via ActionMailer was deferred to keep the delivery logic decoupled and testable without an email server. | Replace `Rails.logger` calls with `UserMailer` + ActionMailer in a future PR. |
| **Utility consumption simulation** | `UtilityService#simulate_consumption` generates random values. Real meter API integration was out of scope for this deliverable. | Integrate real IoT/meter API endpoint in a future iteration. |
| **Frontend test suite** | React component and integration tests (Vitest/React Testing Library) are not included in this deliverable. | Add `vitest` + `@testing-library/react` tests in a dedicated frontend-tests PR. |
