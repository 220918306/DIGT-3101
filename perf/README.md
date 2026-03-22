# REMS performance tests (PT-01 — PT-05)

This folder covers **all** performance-related scenarios for REMS:

| ID | Type | What |
|----|------|------|
| **PT-01** | Rails **Rake** | Time to apply a partial payment on one invoice (`mark_payment!`) |
| **PT-02** | **JMeter** | Mixed API load (units / invoices / appointments) |
| **PT-03** | Rails **Rake** | Time to run monthly invoice generation for active leases |
| **PT-04** | **JMeter** | Concurrent race: many POSTs for the same viewing slot |
| **PT-05** | **JMeter** | Concurrent filtered `GET /units` searches |

Background and NFR text: `PT-02-05-notes.md`.

---

## Prerequisites (shared)

- **Rails API + Postgres** running with data you care about, e.g.:
  ```bash
  cd backend
  rails db:seed
  rails server -p 3000
  ```
- JMeter plans assume the API base URL is **`http://localhost:3000`** unless you change `HOST` / `PORT` / `PROTOCOL` in the plan.

---

## Part A — Non-JMeter tests (Rails Rake): PT-01 & PT-03

These live in `backend/lib/tasks/performance.rake`. Run them from the **`backend`** directory. They use the **`development`** database by default (whatever `RAILS_ENV` is).

### PT-01 — record partial payment (micro-benchmark)

**What it does:** Finds an **unpaid** invoice (or creates one with FactoryBot if none exist), then times **`invoice.mark_payment!(half the balance)`** once. Prints elapsed **milliseconds**. This measures **in-process** model logic, not HTTP.

```bash
cd backend
bin/rails perf:record_payment
```

**Example output:** `PT-01 record_payment elapsed: 12.3 ms`

**Note:** If it creates a sample invoice, **FactoryBot** must be available (normally in `development` + `test` in the Gemfile).

### PT-03 — bulk monthly invoice generation

**What it does:** Runs **`BillingService.new.generate_monthly_invoices`** once over all **active** leases, prints elapsed time, and prints **PASS** if under **30 seconds**, else **FAIL**.

```bash
cd backend
bin/rails perf:invoices
```

**Optional — more leases (~1000) before PT-03:**

```bash
bin/rails perf:seed_thousand_leases
```

That task creates tenants, occupied units, and active leases until there are about **1000** leases total (skips if you already have that many). **Warning:** this writes a lot of rows to your **current** `RAILS_ENV` database—use **development** only unless you intend otherwise.

Then run `bin/rails perf:invoices` again.

---

## Part B — JMeter tests: PT-02, PT-04, PT-05

### Install

1. **Java** (17+ is fine for current JMeter builds).
2. **Apache JMeter 5.6+** — [Download](https://jmeter.apache.org/download_jmeter.cgi) or **macOS:** `brew install jmeter`.

### Important: two ways to use JMeter

| Way | How | When to use |
|-----|-----|----------------|
| **GUI** | Type `jmeter` in **Terminal** → a **separate desktop window** opens (Java app). | First runs, debugging, editing variables, watching results. |
| **CLI (no GUI)** | `jmeter -n -t plan.jmx ...` in Terminal only. | Repeatable runs, CI-style, HTML reports. |

Opening the `.jmx` file in VS Code/Cursor **does not** run the test—you need the **JMeter application** or the **`jmeter -n`** command.

---

### JMeter GUI — step-by-step (first run)

1. **Start Rails** (see Prerequisites).
2. In **Terminal**, run:
   ```bash
   jmeter
   ```
   Wait for the **JMeter window** (not your editor).
3. **File → Open…** → choose a plan under this repo, e.g.  
   `DIGT-3101/perf/rems_api_mixed_load.jmx`
4. **Set `UNIT_ID` (required for any plan that POSTs appointments):**
   - In the **left tree**, click the root **Test Plan** node (e.g. `PT-02 REMS API mixed load`).
   - In the **right panel**, open the **User Defined Variables** section (or the **Arguments** table on the Test Plan).
   - Set **`UNIT_ID`** to a real available unit id from your DB, e.g.:
     ```bash
     cd backend && bin/rails runner "puts Unit.available_units.pick(:id)"
     ```
   - **File → Save** so the value persists.
5. **Add a Listener (or you will see no results):**
   - **Right-click** the **Test Plan** root (top node) → **Add → Listener → Summary Report** (good default).
   - Optionally also **View Results Tree** for debugging (can be slow on big runs).
6. **Run → Start** (green play).  
   - The **timer** in the top-right is **elapsed time** for this run; it stops when the test finishes or when you click **Stop** (square).
   - This plan uses **serialized thread groups** (setUp login, then 50 + 30 + 20 threads with ramp-up and loops), so a full run can take **several minutes**—that is normal.
7. Click **Summary Report** in the tree to see **# Samples**, **Average**, **Error %**, etc.

**If Error % is high:** use **View Results Tree**, pick a failed line, and read **Response data** (e.g. **401** = login or JWT; **422** = validation).

**If login fails:** PT-02/PT-04 use **`TENANT_EMAIL`** / **`TENANT_PASSWORD`** (e.g. `tenant1@rems.com` / `password123`). PT-05 uses **`USER_EMAIL`** / **`USER_PASSWORD`** (defaults `clerk@rems.com` / `password123`).

---

### Variables (all JMeter plans)

| Variable | Default | Purpose |
|----------|---------|---------|
| `HOST` | `localhost` | API host |
| `PORT` | `3000` | API port |
| `PROTOCOL` | `http` | Use `https` behind TLS |
| `TENANT_EMAIL` | `tenant1@rems.com` | Login for PT-02 / PT-04 |
| `TENANT_PASSWORD` | `password123` | Login password |
| `UNIT_ID` | `1` | **Set to a real id.** Unit must be **`available: true`** and **`status: available`** for `POST /appointments`. |
| `RACE_SLOT_ISO` | (PT-04) | Same slot for all race threads, e.g. `2030-06-15T14:00:00` (far future avoids “24h ahead” issues). |
| `USER_EMAIL` | `clerk@rems.com` | PT-05 login (comment in plan says tenant works too) |
| `USER_PASSWORD` | `password123` | PT-05 login |

### Auth flow (built into the `.jmx` files)

1. **setUp Thread Group** runs first: `POST /api/v1/auth/login` with JSON body.
2. **JSR223 PostProcessor** stores `token` in JMeter property **`JWT`**.
3. Other requests send **`Authorization: Bearer ${__P(JWT)}`**.

---

### JMeter CLI (no GUI)

```bash
cd /path/to/DIGT-3101/perf
mkdir -p results
jmeter -n -t rems_api_mixed_load.jmx -l results/pt02.jtl -e -o results/pt02-report
```

Open **`results/pt02-report/index.html`** in a browser. Swap **`-t rems_....jmx`** for PT-04 or PT-05.

---

### JMeter plan summary

| File | PT | What it does |
|------|----|----------------|
| `rems_api_mixed_load.jmx` | PT-02 | ~100 users (50+30+20 thread groups): GET `units?available_only=true`, GET `invoices`, POST `appointments` (unique times). |
| `rems_viewing_race_condition.jmx` | PT-04 | 20 threads, synchronizing timer, **same** `unit_id` + `scheduled_time` → expect **~1× 201**, **~19× 409**. |
| `rems_units_search_load.jmx` | PT-05 | 50×20 GET `/units` with random `min_price`, `max_price`, `min_size`, `tier`, `available_only`. |

#### PT-04 — quick manual check

After a run, in **Summary Report** / **Aggregate Report**, count status codes: ~one **201**, rest **409** on the appointment sampler.

Optional DB check (replace ids/time):

```bash
cd backend
bin/rails runner "puts Appointment.where(unit_id: YOUR_UNIT_ID, scheduled_time: Time.zone.parse('YOUR_ISO')).count"
```

Expect **1** row for that slot.

#### PT-05 — data volume

For realistic search latency, seed **many** units (10k+). With only `db:seed`, numbers are still useful for **relative** comparison before/after changes.

---

## NFR thresholds (from `PT-02-05-notes.md`)

- **PT-02:** p95 &lt; 500 ms, p99 &lt; 2000 ms, error rate &lt; 5% (treat expected 409s as you see fit).
- **PT-05:** Tune after representative data; use **Aggregate Report** percentile columns.
- **PT-01 / PT-03:** Rake tasks print timing only; PT-03 has an explicit **30 s** pass/fail line.
