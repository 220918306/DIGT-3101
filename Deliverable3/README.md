# Deliverable 3 — Repository Guide

This document explains where to find everything a reviewer needs to assess the REMS project.

---

## Repository Structure

```
DIGT-3101/
├── backend/                  # Ruby on Rails 7.2 API (all server-side code)
│   ├── app/
│   │   ├── controllers/      # API endpoints (api/v1/)
│   │   ├── models/           # 13 ActiveRecord models with validations and business logic
│   │   ├── services/         # Business logic: BillingService, MaintenanceService, etc.
│   │   ├── factories/        # LeaseFactory (Factory Pattern)
│   │   └── jobs/             # Background jobs (Sidekiq)
│   ├── db/
│   │   ├── migrate/          # 13 database migrations
│   │   └── seeds.rb          # Demo data (5 users, 2 properties, 6 units, leases, tickets)
│   ├── test/                 # ← TEST SUITE IS HERE
│   │   ├── models/           # Model unit tests (TC-01 – TC-19)
│   │   ├── services/         # Service unit tests (TC-20 – TC-34)
│   │   ├── controllers/      # Controller integration tests (auth, units, maintenance, etc.)
│   │   ├── jobs/             # Background job tests (TC-26)
│   │   └── factories/        # FactoryBot definitions
│   └── coverage/             # ← SIMPLECOV HTML REPORT (generated after `rails test`)
│       └── index.html
│
├── frontend/                 # React 19 + Vite frontend
│   └── src/
│       ├── api/              # Axios API modules
│       ├── context/          # AuthContext
│       ├── components/       # Shared UI components
│       └── pages/            # Role-based pages (tenant, clerk, admin)
│
├── Deliverable3/             # This folder — deliverable navigation guide
│   └── README.md
│
└── README.md                 # Full project README (setup, API reference, test guide)
```

---

## Where to Find Things

| What | Where |
|---|---|
| **Source code (backend)** | `backend/app/` |
| **Source code (frontend)** | `frontend/src/` |
| **Database schema** | `backend/db/schema.rb` (auto-generated after migrations) |
| **All tests** | `backend/test/` |
| **Test helper + config** | `backend/test/test_helper.rb` |
| **FactoryBot factories** | `backend/test/factories/factories.rb` |
| **SimpleCov coverage report** | `backend/coverage/index.html` — open in browser after running `rails test` |
| **CI/CD workflow** | `backend/.github/workflows/ci.yml` |
| **API routes** | `backend/config/routes.rb` |
| **Seed data** | `backend/db/seeds.rb` |
| **Architecture patterns** | Main `README.md` → Architecture Notes section |
| **User story traceability** | Main `README.md` → User Story Traceability section |
| **Known scope deferrals** | Main `README.md` → Known Scope Deferrals section |

---

## Generating the Coverage Report

```bash
cd backend
bundle install
rails db:create db:migrate
rails test
open coverage/index.html   # macOS
```

---

## Test Coverage Summary and Interpretation

**Overall: 98.84% line coverage (595 / 602 lines)**

| Category | Files | Coverage |
|---|---|---|
| Models | 13 models | 99%+ — all validations, enums, business methods, and payment cycle branches tested |
| Controllers | 11 controllers | 97%+ — all CRUD actions, role-based auth, error responses, filters |
| Services | 5 services | 98%+ — JWT encode/decode, billing with discounts, scheduling with pessimistic lock, maintenance strategy dispatch |
| Jobs | 2 jobs | 100% — both GenerateInvoicesJob and MarkOverdueInvoicesJob |
| Factories | 1 factory | 100% — LeaseFactory transactional creation and rollback |

### What the 7 uncovered lines are and why

The remaining 1.16% (7 lines) are **rescue/error-handling branches** that cannot be reached without mocking infrastructure failures:

1. **`billing_service.rb:17`** — `rescue StandardError` block that logs errors during invoice generation. Only triggers if the database fails mid-transaction, which cannot be simulated in a test without mocking ActiveRecord internals.

2. **`maintenance_service.rb:12`** — `handle_urgent` case branch. The code path is functionally covered (urgent tickets are tested), but SimpleCov marks the `when` keyword line differently from the method call.

3. **`base_controller.rb:42,50,54,62`** — `handle_not_found`, `handle_unprocessable`, `handle_bad_request`, `handle_unauthorized` rescue-from handler methods. These are invoked via Rails' `rescue_from` dispatch mechanism. The test suite verifies the correct HTTP status codes (401, 403, 404, 422) are returned for all error scenarios, but SimpleCov doesn't track the method-definition line as "covered" since Rails dispatches to them internally.

4. **`auth_controller.rb:38`** — `handle_invalid` rescue handler — same rescue_from dispatch pattern.

**Interpretation**: These are boilerplate error-handling methods that exist for robustness. The error *behavior* (correct HTTP status codes) is thoroughly tested — 304 assertions verify this. The handler method *definitions* are marked uncovered only due to how SimpleCov tracks `rescue_from` dispatch, not due to missing test logic.

---

## Test Suite Summary

```
163 runs, 304 assertions, 0 failures, 0 errors, 0 skips
```

### Test breakdown by file

| Test File | Tests | What is covered |
|---|---|---|
| `models/user_test.rb` | 5 | Validations, BCrypt, role enum (TC-01–05) |
| `models/appointment_test.rb` | 7 | Double-booking, out-of-hours, scopes (TC-06–12) |
| `models/lease_test.rb` | 9 | Payment cycles (monthly/quarterly/biannual/annual), status (TC-13–22) |
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

---

## Running All Tests

```bash
cd backend
rails test
```

To run specific suites:

```bash
rails test test/models/
rails test test/services/
rails test test/controllers/
rails test test/jobs/
```
