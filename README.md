# Real Estate Management System (REMS)

A full-stack property management platform built with **Ruby on Rails 7.2** (API) and **React 19** (Vite).

---

## Table of Contents

1. [Tech Stack](#tech-stack)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Running the Tests](#running-the-tests)
5. [Demo Credentials](#demo-credentials)
6. [API Reference](#api-reference)
7. [Architecture Notes](#architecture-notes)
8. [User Story Traceability](#user-story-traceability)
9. [Known Scope Deferrals](#known-scope-deferrals)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Ruby 3.3.5, Rails 7.2 (API mode) |
| Database | PostgreSQL 14+ |
| Auth | JWT (ruby-jwt) + BCrypt |
| Background Jobs | Sidekiq + Sidekiq-Cron + Redis |
| Frontend | React 19, Vite, React Router v7, TailwindCSS |
| HTTP Client | Axios |
| Backend Testing | Minitest, FactoryBot, SimpleCov |
| Frontend Testing | Vitest, React Testing Library, jsdom |

---

## Prerequisites

Install these before you start:

| Tool | Required Version | How to check |
|---|---|---|
| Ruby | 3.3.5 | `ruby --version` |
| Bundler | 2.x | `bundler --version` |
| Node.js | 20+ (LTS) | `node --version` |
| npm | 9+ | `npm --version` |
| PostgreSQL | 14+ | `psql --version` |

> **macOS:** Install Ruby via rbenv — `rbenv install 3.3.5 && rbenv local 3.3.5`
>
> **Node version note:** Frontend tooling in this repo requires Node 20+. If you use nvm:
> `nvm install 20 && nvm use 20`

### Install prerequisites (macOS)

If any prerequisite is missing, use:

```bash
# Homebrew (if needed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Ruby via rbenv
brew install rbenv ruby-build
rbenv install 3.3.5
rbenv local 3.3.5
rbenv rehash

# Bundler
gem install bundler

# Node.js + npm via nvm
brew install nvm
mkdir -p ~/.nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix nvm)/nvm.sh" ] && . "$(brew --prefix nvm)/nvm.sh"
nvm install 20
nvm use 20

# PostgreSQL
brew install postgresql@14
brew services start postgresql@14
```

### Install prerequisites (Windows)

If any prerequisite is missing, use:

1. Install Ruby 3.3.5 using [RubyInstaller for Windows](https://rubyinstaller.org/).
2. Install Bundler:
   ```powershell
   gem install bundler
   ```
3. Install Node.js 20+ (LTS):
   - Option A: install from [nodejs.org](https://nodejs.org/)
   - Option B: use [nvm-windows](https://github.com/coreybutler/nvm-windows):
     ```powershell
     nvm install 20.19.0
     nvm use 20.19.0
     ```
4. Install PostgreSQL 14+ from [postgresql.org](https://www.postgresql.org/download/windows/).
5. Verify versions:
   ```powershell
   ruby --version
   bundler --version
   node --version
   npm --version
   psql --version
   ```

---

## Quick Start

### Step 1 — Clone the repo

```bash
git clone https://github.com/220918306/DIGT-3101.git
cd DIGT-3101
```

---

### Step 2 — Backend setup

```bash
cd backend
bundle install
```

Set your Postgres credentials:

```bash
export DB_USERNAME=postgres
export DB_PASSWORD=yourpassword
export DB_HOST=localhost
```

> Or open `config/database.yml` and replace the `ENV[...]` values directly.

Create, migrate, and seed the database:

```bash
rails db:create db:migrate db:seed
```

Start the Rails server:

```bash
rails server -p 3000
```

API is live at `http://localhost:3000/api/v1`.

---

### Step 3 — Frontend setup

Open a **second terminal**:

```bash
# ensure correct Node version (from .nvmrc)
nvm use
cd frontend
npm install
npm run dev
```

App is live at `http://localhost:5173`.

> All `/api` requests are automatically proxied to `http://localhost:3000` — no extra config needed.

---

## Running the Tests

> You do **not** need the app servers running to run tests.

---

### Backend

```bash
cd backend
bundle exec rails test
```

**Expected output:**

```
240 runs, 476 assertions, 0 failures, 0 errors, 0 skips 
Line Coverage: 98.01% (738 / 753)

A full HTML coverage report is saved to `backend/coverage/index.html` — open it in any browser.

---

### Frontend

```bash
nvm use
cd frontend
npm test -- --run
```

**Expected output:**

```
Test Files  8 passed (8)
     Tests  36 passed (36)
```

---

### Run a single test file

**Backend:**
```bash
cd backend
bundle exec rails test test/services/billing_service_test.rb
```

**Frontend:**
```bash
cd frontend
npm test -- --run src/pages/tenant/MyInvoices.test.jsx
```

---

### Backend test files — TC order (200 tests total)

| TC | Test File | What is covered |
|---|---|---|
| TC-01 | `models/user_test.rb` | User validations, BCrypt password hashing, role enum |
| TC-02 | `controllers/auth_controller_test.rb` | Login (valid/invalid), register (valid/duplicate/missing fields) |
| TC-03 | `models/appointment_test.rb` | Double-booking prevention, out-of-hours guard, appointment scopes |
| TC-03 | `controllers/appointments_controller_test.rb` | Book viewing, conflict 409, reschedule, cancel, cross-tenant protection |
| TC-03 | `services/scheduling_service_test.rb` | Pessimistic lock, conflict detection, available slot listing |
| TC-04 | `controllers/units_controller_test.rb` | Unit listing, filters (price/size/tier/status), detail, available slots, 401/404 |
| TC-05 | `services/notification_service_test.rb` | Upcoming reminder, confirmed-only filter, cancelled appointment exclusion |
| TC-06 | `controllers/applications_controller_test.rb` | Submit, approve, reject, status filter, role guards, TC-22 cancel |
| TC-07 | `services/billing_service_test.rb` | Quarterly cycle: skips months 2 & 3, generates on month 4 |
| TC-08 | `services/billing_service_test.rb` | Discount line item present for 2-lease tenant (10% tier) |
| TC-09 | `services/billing_service_test.rb` | Re-running billing does not duplicate invoice for same period |
| TC-10 | `models/unit_test.rb` | `mark_as_occupied!`, `mark_as_available!`, unit scopes |
| TC-11 | `services/utility_service_test.rb` | Utility charge breakdown (electricity/water/waste), idempotency |
| TC-12 | `controllers/invoices_controller_test.rb` | Invoice list, detail with line items, generate endpoint, access control |
| TC-12 | `jobs/generate_invoices_job_test.rb` | Job perform, idempotency guard |
| TC-13 | `services/notification_service_test.rb` | Overdue reminder increments counter, sets last_reminder_at, skips paid |
| TC-14 | `services/notification_service_test.rb` | Reminders at 1, 7, 14, 30-day overdue intervals; partial-pay still reminded |
| TC-15 | `jobs/mark_overdue_invoices_job_test.rb` | Marks past-due unpaid invoices overdue, skips paid and future invoices |
| TC-16 | `controllers/payments_controller_test.rb` | Full payment, partial payment, zero amount rejection, already-paid guard |
| TC-17 | `models/invoice_test.rb` | `overdue?` method, remaining balance calculation |
| TC-18 | `models/lease_test.rb` | Payment cycles (monthly/quarterly/biannual/annual), status transitions |
| TC-19 | `models/lease_factory_test.rb` | Factory Pattern: atomic transaction, rollback on failure |
| TC-20 | `services/maintenance_service_test.rb` | Strategy dispatch, FCFS queue, damage billing, priority ordering |
| TC-21 | `controllers/leases_controller_test.rb` | Unit history via `unit_id` filter, all statuses returned, tenant scoping |
| TC-22 | `controllers/applications_controller_test.rb` | Tenant cancels own pending application, ownership check, state guard |
| TC-23 | `controllers/maintenance_tickets_controller_test.rb` | Multi-lease tenant creation, status lifecycle open→in_progress→completed |
| TC-24 | `controllers/leases_controller_test.rb` | Lease renewal creates new lease, expires old, inherits cycle, role guard |
| TC-25 | `services/jwt_service_test.rb` | Encode/decode, expired token rejection, tampered token rejection |
| TC-26 | `controllers/utility_consumptions_controller_test.rb` | List and detail, tenant vs clerk access |
| TC-27 | `controllers/reports_controller_test.rb` | Occupancy, revenue, maintenance reports; date filters; role guards |
| TC-28 | `test/system/end_to_end_flows_test.rb` | Tenant signs in and views available units (Capybara E2E) |
| TC-33 | `services/billing_service_test.rb` | Quarterly cycle: skips months 2+3, generates on month 4 |
| TC-34 | `services/billing_service_test.rb` | Annual cycle: skips at 6m and 11m, generates at month 12 |

---

### Frontend test files — TC order (36 tests total)

| TC | Test File | What is covered |
|---|---|---|
| TC-01 | `src/pages/Login.test.jsx` | Email/password fields render, sign in button present |
| TC-02 | `src/pages/Register.test.jsx` | All form fields render, heading, sign-in link, error banner on API failure |
| TC-04 | `src/pages/tenant/UnitSearch.test.jsx` | Units load from API and display correctly |
| TC-10 | `src/pages/tenant/MaintenanceRequest.test.jsx` | Priority buttons, ticket list, submit success, empty description error, API error |
| TC-11 | `src/pages/tenant/MyInvoices.test.jsx` | Invoice list, Pay Now/View buttons, detail modal with line items, payment success |
| TC-12 | `src/pages/clerk/InvoiceManagement.test.jsx` | Invoice table, revenue/outstanding totals, generate success and error messages |
| TC-23 | `src/pages/clerk/MaintenanceQueue.test.jsx` | Queue listing, empty state, Update/Bill Damage buttons, status modal |
| TC-25 | `src/pages/clerk/ApplicationsList.test.jsx` | Application list, Approve/Reject scoped to pending, modals, success messages |

---

## Demo Credentials

After running `rails db:seed`:

| Role | Email | Password |
|---|---|---|
| Admin | admin@rems.com | password123 |
| Clerk | clerk@rems.com | password123 |
| Tenant 1 (active lease) | tenant1@rems.com | password123 |
| Tenant 2 (active lease) | tenant2@rems.com | password123 |
| Tenant 3 (pending application) | tenant3@rems.com | password123 |

---

## API Reference

All endpoints are prefixed with `/api/v1`. Protected endpoints require:

```
Authorization: Bearer <token>
```

Get your token from `POST /auth/login` or `POST /auth/register`.

### Auth
| Method | Endpoint | Body | Returns |
|---|---|---|---|
| POST | `/auth/login` | `{ email, password }` | `{ token, user }` |
| POST | `/auth/register` | `{ name, email, password, phone }` | `{ token, user }` |

### Units
| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/units` | Any | List units. Filter: `?status=available&min_price=1000` |
| GET | `/units/:id` | Any | Unit detail |
| GET | `/units/:id/available_slots` | Any | Open 1-hour viewing slots |

### Appointments
| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/appointments` | Any | List your appointments |
| POST | `/appointments` | Tenant | Book a viewing (pessimistic lock prevents double-booking) |
| PATCH | `/appointments/:id` | Any | Reschedule or update |
| DELETE | `/appointments/:id` | Any | Cancel |

### Applications
| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/applications` | Any | Tenant sees own; Clerk/Admin see all |
| POST | `/applications` | Tenant | Submit a rental application |
| DELETE | `/applications/:id` | Tenant | Cancel own pending application (TC-22) |
| PATCH | `/applications/:id/approve` | Clerk/Admin | Approve — creates lease, marks unit occupied |
| PATCH | `/applications/:id/reject` | Clerk/Admin | Reject with reason |

### Leases
| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/leases` | Any | Tenant sees own; Clerk/Admin see all. Filter: `?unit_id=5` for history (TC-21) |
| GET | `/leases/:id` | Any | Lease detail |
| POST | `/leases` | Clerk/Admin | Create lease manually |
| POST | `/leases/:id/renew` | Clerk/Admin | Renew lease — creates new, expires old (TC-24) |

### Invoices and Payments
| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/invoices` | Any | Tenant sees own; Clerk/Admin see all. Filter: `?status=overdue` |
| GET | `/invoices/:id` | Any | Invoice with full line items |
| POST | `/invoices/generate` | Clerk/Admin | Trigger monthly invoice generation |
| POST | `/payments` | Tenant | Record full or partial payment |

### Maintenance Tickets
| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/maintenance_tickets` | Any | Tenant sees own; Clerk gets priority-sorted queue |
| POST | `/maintenance_tickets` | Tenant | Submit new ticket |
| PATCH | `/maintenance_tickets/:id` | Clerk/Admin | Update status |
| POST | `/maintenance_tickets/:id/bill_damage` | Admin | Charge tenant for damage |

### Reports
| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/reports/occupancy` | Clerk/Admin | Per-property occupancy % |
| GET | `/reports/revenue` | Clerk/Admin | Monthly revenue breakdown |
| GET | `/reports/maintenance` | Clerk/Admin | Ticket volume and resolution times |

---

## Architecture Notes

| Pattern | Location | Purpose |
|---|---|---|
| **Factory Pattern** | `app/factories/lease_factory.rb` | Wraps lease creation, unit update, and notification in one atomic transaction |
| **Strategy Pattern** | `app/services/maintenance_service.rb` | Dispatches to the right handler by priority — adding a new tier needs one method, no if/case chains |
| **Observer Pattern** | `app/models/maintenance_ticket.rb` | `after_create` auto-escalates emergency tickets without any controller involvement |
| **Pessimistic Locking** | `app/services/scheduling_service.rb` | `SELECT FOR UPDATE` ensures two tenants racing for the same slot cannot both succeed |
| **FCFS Queue** | `app/services/maintenance_service.rb` | Ordered by priority tier then `created_at` — earlier submissions handled first within same priority |
| **Idempotent Billing** | `app/services/billing_service.rb` | Checks for existing invoice before creating — safe to retry via cron without duplicating charges |

---

## User Story Traceability

| FR | Description | Status | Notes |
|---|---|---|---|
| FR-01 | Search and filter available units | Implemented | Filters: status, price, size, tier, purpose |
| FR-02 | View unit detail | Implemented | Returns unit + property info |
| FR-03 | Book a unit viewing | Implemented | Pessimistic lock prevents double-booking |
| FR-04 | Submit a rental application | Implemented | Tenant-only, tied to a specific unit |
| FR-05 | Approve or reject application | Implemented | Clerk/Admin; triggers LeaseFactory on approval |
| FR-06 | Create lease from approved application | Implemented | Atomic transaction via Factory Pattern |
| FR-07 | Generate monthly invoices | Implemented | Idempotent; safe to retry via Sidekiq Cron |
| FR-08 | View invoice with line items | Implemented | Base rent, utilities, discounts, damage fees |
| FR-09 | Submit maintenance request | Implemented | Multi-lease tenants must supply `lease_id` |
| FR-10 | Record a payment | Implemented | Full and partial payments handled automatically |
| FR-11 | Calculate utility charges | Implemented | Simulated consumption; rates in `UtilityService` |
| FR-12 | View maintenance ticket queue | Implemented | FCFS within priority tier |
| FR-13 | Tenant self-registration | Implemented | Creates User + Tenant in one request |
| FR-14 | Update maintenance ticket status | Implemented | Clerk/Admin only |
| FR-15 | Bill tenant for damage | Implemented | Creates invoice + line item; Admin only |
| FR-16 | Occupancy report | Implemented | Per-property occupancy percentages |
| FR-17 | Revenue report | Implemented | Monthly revenue breakdown |
| FR-18 | Maintenance report | Implemented | Ticket volume and resolution stats |
| NFR-01 | JWT stateless authentication | Implemented | HS256, 24-hour expiry, role-based access control |
| NFR-08 | Concurrent booking safety | Implemented | `SELECT FOR UPDATE` in `SchedulingService` |
| NFR-09 | FCFS maintenance queue | Implemented | Priority tier + `created_at` ordering |
| NFR-10 | Notifications | Partially Implemented | All events logged via `Rails.logger`; real SMTP deferred (see below) |

---

## Known Scope Deferrals

| Item | Reason | Future Work |
|---|---|---|
| **Email delivery** | `NotificationService` logs all events to `Rails.logger`. Real SMTP via ActionMailer was deferred to keep the service decoupled and testable without an email server. | Replace log calls with `UserMailer` + ActionMailer in a future PR |
| **Utility consumption** | `UtilityService#simulate_consumption` generates deterministic values. Real IoT/meter integration was out of scope. | Integrate real meter API in a future iteration |
| **Performance tests PT-02/04/05** | JMeter plans live in `perf/*.jmx`; runbook is `perf/README.md`. Requires Java, JMeter, and Rails running (e.g. localhost:3000). | Run `jmeter -n -t perf/<plan>.jmx` or open plans in JMeter GUI |
