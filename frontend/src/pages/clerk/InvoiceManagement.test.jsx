import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { vi } from "vitest";
import { BrowserRouter } from "react-router-dom";
import { AuthProvider } from "../../context/AuthContext";
import InvoiceManagement from "./InvoiceManagement";
import * as invoicesApi from "../../api/invoices";

vi.mock("../../api/invoices");

const mockInvoices = [
  { id: 1, tenant_id: 10, billing_month: "2026-03-01", amount: "2500.00",
    amount_paid: "0.00", remaining: "2500.00", status: "unpaid", due_date: "2026-03-31" },
  { id: 2, tenant_id: 11, billing_month: "2026-02-01", amount: "2600.00",
    amount_paid: "2600.00", remaining: "0.00", status: "paid",   due_date: "2026-02-28" },
  { id: 3, tenant_id: 12, billing_month: "2026-01-01", amount: "2400.00",
    amount_paid: "0.00", remaining: "2400.00", status: "overdue", due_date: "2026-01-31" },
];

function renderPage() {
  return render(
    <BrowserRouter>
      <AuthProvider>
        <InvoiceManagement />
      </AuthProvider>
    </BrowserRouter>,
  );
}

describe("TC-12: Invoice Management page (clerk)", () => {
  beforeEach(() => {
    vi.spyOn(invoicesApi, "getInvoices").mockResolvedValue({ data: mockInvoices });
  });

  test("renders heading and Generate Monthly Invoices button", async () => {
    renderPage();
    await waitFor(() => {
      expect(screen.getByRole("heading", { name: /invoice management/i })).toBeInTheDocument();
    });
    expect(screen.getByRole("button", { name: /generate monthly invoices/i })).toBeInTheDocument();
  });

  test("displays all loaded invoices in the table", async () => {
    renderPage();
    await waitFor(() => {
      // Invoice IDs rendered as "#1", "#2", "#3" — use exact text to avoid matching "Tenant #10"
      expect(screen.getAllByText("#1").length).toBeGreaterThan(0);
      expect(screen.getAllByText("#2").length).toBeGreaterThan(0);
      expect(screen.getAllByText("#3").length).toBeGreaterThan(0);
    });
  });

  test("shows collected revenue and outstanding amounts from paid/unpaid invoices", async () => {
    renderPage();
    await waitFor(() => {
      // Summary cards show formatted totals
      expect(screen.getAllByText(/\$2600\.00/i).length).toBeGreaterThan(0);
      expect(screen.getAllByText(/\$4900\.00/i).length).toBeGreaterThan(0);
    });
  });

  test("shows success message after clicking Generate Monthly Invoices", async () => {
    vi.spyOn(invoicesApi, "generateInvoices").mockResolvedValueOnce({
      data: { message: "3 invoices generated" },
    });

    renderPage();

    await waitFor(() => screen.getByRole("button", { name: /generate monthly invoices/i }));
    fireEvent.click(screen.getByRole("button", { name: /generate monthly invoices/i }));

    await waitFor(() => {
      expect(screen.getByText(/3 invoices generated/i)).toBeInTheDocument();
    });
  });

  test("shows error message when invoice generation fails", async () => {
    vi.spyOn(invoicesApi, "generateInvoices").mockRejectedValueOnce({
      response: { data: { error: "Unauthorized" } },
    });

    renderPage();

    await waitFor(() => screen.getByRole("button", { name: /generate monthly invoices/i }));
    fireEvent.click(screen.getByRole("button", { name: /generate monthly invoices/i }));

    await waitFor(() => {
      expect(screen.getByText(/unauthorized/i)).toBeInTheDocument();
    });
  });
});
