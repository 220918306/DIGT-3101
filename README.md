# Real Estate Management System (REMS)

A full-stack property management platform built with **Ruby on Rails 7.2** (API) and **React 18** (Vite). Tenants can search units, book viewings, apply for leases, pay invoices, and submit maintenance requests. Clerks manage applications and maintenance queues. Admins view system-wide reports.

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
| Frontend | React 18, Vite, React Router v6 |
| Styling | TailwindCSS 3 |
| HTTP Client | Axios |
| Testing | Minitest, FactoryBot, Shoulda Matchers, DatabaseCleaner |

---

## Prerequisites

Make sure the following are installed before you start:

```bash
ruby --version      # 3.3.5
rails --version     # 7.2.x
node --version      # 18+
npm --version       # 9+
psql --version      # 14+
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
├── backend/                  # Rails 7.2 API
│   ├── app/
│   │   ├── controllers/api/v1/   # All API controllers
│   │   ├── models/               # 13 domain models
│   │   ├── services/             # Business logic services
│   │   ├── factories/            # LeaseFactory (Factory Pattern)
│   │   └── jobs/                 # Sidekiq background jobs
│   ├── config/
│   │   ├── routes.rb
│   │   └── initializers/
│   ├── db/
│   │   ├── migrate/              # 13 migrations
│   │   └── seeds.rb              # Demo data
│   └── test/                     # Minitest suite (TC-01 – TC-34)
│
└── frontend/                 # React 18 + Vite
    └── src/
        ├── api/              # Axios modules per resource
        ├── context/          # AuthContext (JWT storage)
        ├── components/       # Navbar, StatusBadge, LoadingSpinner
        └── pages/
            ├── tenant/       # Dashboard, UnitSearch, MyInvoices, Maintenance
            ├── clerk/        # Dashboard, Applications, MaintenanceQueue, Invoices
            └── admin/        # Dashboard, Reports
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

The app uses environment variables for database credentials. Create a `.env` file or export directly:

```bash
export DB_USERNAME=postgres
export DB_PASSWORD=yourpassword
export DB_HOST=localhost
```

Or edit `config/database.yml` and replace `<%= ENV["DB_USERNAME"] %>` etc. with your local values.

### 4. Create and migrate the database

```bash
rails db:create
rails db:migrate
```

### 5. Seed demo data

```bash
rails db:seed
```

This creates 5 users, 2 properties, 6 units, 3 leases, invoices, maintenance tickets, and appointments so you can log in and explore immediately.

Expected output:
```
Admin:   admin@rems.com  / password123
Clerk:   clerk@rems.com  / password123
Tenant1: tenant1@rems.com / password123 (active lease)
Tenant2: tenant2@rems.com / password123 (active lease)
Tenant3: tenant3@rems.com / password123 (pending application)
```

### 6. Start the Rails server

```bash
rails server -p 3000
```

The API is now available at `http://localhost:3000/api/v1`.

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

The `.env` file should already exist with:
```
VITE_API_URL=http://localhost:3000
```

If it doesn't, create it manually with the line above.

### 4. Start the dev server

```bash
npm run dev
```

The app is now available at `http://localhost:5173`.

> Vite proxies all `/api` requests to `http://localhost:3000`, so the backend and frontend can run simultaneously without CORS issues.

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
| **Admin** | admin@rems.com | password123 | View reports, manage all data |
| **Clerk** | clerk@rems.com | password123 | Approve applications, manage maintenance queue, generate invoices |
| **Tenant 1** | tenant1@rems.com | password123 | Active lease — view invoices, submit maintenance requests |
| **Tenant 2** | tenant2@rems.com | password123 | Active lease — same as Tenant 1 |
| **Tenant 3** | tenant3@rems.com | password123 | Pending application — search units, book viewings |

---

## API Reference

All endpoints are prefixed with `/api/v1`. Protected endpoints require the header:
```
Authorization: Bearer <your_jwt_token>
```

### Authentication (public)

| Method | Endpoint | Body | Returns |
|---|---|---|---|
| POST | `/auth/login` | `{ email, password }` | `{ token, user }` |
| POST | `/auth/register` | `{ name, email, password, phone }` | `{ token, user }` |

### Units

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/units` | Any | List units (filter by `status`, `property_id`, `min_price`, `max_price`) |
| GET | `/units/:id` | Any | Unit detail |
| GET | `/units/:id/available_slots` | Any | List available 1-hour booking slots |

### Appointments

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/appointments` | Any | List own appointments |
| POST | `/appointments` | Tenant | Book a viewing (uses pessimistic lock to prevent double-booking) |
| PATCH | `/appointments/:id` | Any | Update appointment |
| DELETE | `/appointments/:id` | Any | Cancel appointment |

### Applications & Leases

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/applications` | Tenant/Clerk/Admin | Tenant sees own; Clerk/Admin see all pending |
| POST | `/applications` | Tenant | Submit a rental application |
| PATCH | `/applications/:id/approve` | Clerk/Admin | Approve → creates lease automatically |
| PATCH | `/applications/:id/reject` | Clerk/Admin | Reject application |
| GET | `/leases` | Any | List leases |
| GET | `/leases/:id` | Any | Lease detail |
| POST | `/leases` | Clerk/Admin | Create lease manually |

### Invoices & Payments

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/invoices` | Any | Tenant sees own; Clerk/Admin see all |
| GET | `/invoices/:id` | Any | Invoice with line items and payment history |
| POST | `/invoices/generate` | Clerk/Admin | Trigger monthly invoice generation |
| POST | `/payments` | Tenant | Record a payment (handles full and partial) |

### Maintenance

| Method | Endpoint | Role | Description |
|---|---|---|---|
| GET | `/maintenance_tickets` | Any | Tenant sees own; Clerk gets FCFS priority queue |
| POST | `/maintenance_tickets` | Tenant | Submit a ticket |
| PATCH | `/maintenance_tickets/:id` | Clerk/Admin | Update ticket status |
| POST | `/maintenance_tickets/:id/bill_damage` | Admin | Bill tenant for damage |

### Reports (Admin/Clerk only)

| Method | Endpoint | Description |
|---|---|---|
| GET | `/reports/occupancy` | Per-property occupancy percentages |
| GET | `/reports/revenue` | Monthly revenue breakdown |
| GET | `/reports/maintenance` | Ticket volume and resolution stats |

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

Run a single test file:
```bash
rails test test/services/billing_service_test.rb
```

### Test coverage (30 tests, TC-01 – TC-34)

| File | Test Cases | What's tested |
|---|---|---|
| `test/models/user_test.rb` | TC-01 – TC-05 | Validations, BCrypt hashing, role enum |
| `test/models/appointment_test.rb` | TC-06 – TC-12 | Double-booking prevention, out-of-hours rejection |
| `test/models/lease_test.rb` | TC-13 – TC-19 | Payment cycles, status transitions |
| `test/services/billing_service_test.rb` | TC-20 – TC-27 | Idempotency, discount tiers, partial payments |
| `test/services/maintenance_service_test.rb` | TC-28 – TC-34 | Strategy dispatch, FCFS queue, damage billing |

Expected output:
```
30 runs, 30 assertions, 0 failures, 0 errors, 0 skips
```

---

## Background Jobs

The app uses **Sidekiq** for background processing. To enable scheduled jobs:

### 1. Start Redis

```bash
redis-server
```

### 2. Start Sidekiq (in a separate terminal)

```bash
cd DIGT-3101/backend
bundle exec sidekiq
```

### Scheduled jobs

| Job | Schedule | What it does |
|---|---|---|
| `GenerateInvoicesJob` | 1st of each month at 00:05 | Generates monthly invoices for all active leases (idempotent — safe to retry) |
| `MarkOverdueInvoicesJob` | Daily at 01:00 | Marks unpaid past-due invoices as `overdue` |

> Without Sidekiq running, you can still manually trigger invoice generation via `POST /api/v1/invoices/generate` from the clerk dashboard.

---

## Architecture Notes

| Pattern | Where | Why |
|---|---|---|
| **Factory Pattern** | `LeaseFactory` | Encapsulates the multi-step lease creation transaction (application → lease → unit status → notification) |
| **Strategy Pattern** | `MaintenanceService#handle_by_priority` | Dispatches emergency vs. standard tickets without branching logic — new priorities = new method + hash entry |
| **Observer Pattern** | `MaintenanceTicket after_create` | Auto-escalates emergency tickets to `urgent` status on creation without coupling the controller |
| **Pessimistic Locking** | `SchedulingService#book_appointment` | `SELECT FOR UPDATE` prevents two tenants from booking the same slot simultaneously (NFR-08) |
| **FCFS Queue** | `MaintenanceService#prioritized_queue` | Orders tickets by priority tier then `created_at` — guarantees first-come-first-served fairness (NFR-09) |
| **Idempotent Billing** | `BillingService#generate_monthly_invoices` | Skips units with an existing invoice for the current period — safe to run multiple times or retry on failure |
