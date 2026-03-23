import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { vi } from "vitest";
import { BrowserRouter } from "react-router-dom";
import { AuthProvider } from "../../context/AuthContext";
import MyInvoices from "./MyInvoices";
import * as invoicesApi from "../../api/invoices";
import * as paymentsApi from "../../api/payments";
import * as leasesApi from "../../api/leases";
import * as lettersApi from "../../api/letters";

vi.mock("../../api/invoices");
vi.mock("../../api/payments");
vi.mock("../../api/leases");
vi.mock("../../api/letters");

const mockInvoices = [
  { id: 1, billing_month: "2026-03-01", amount: "2500.00", amount_paid: "0.00",
    remaining: "2500.00", status: "unpaid", due_date: "2026-03-31" },
  { id: 2, billing_month: "2026-02-01", amount: "2500.00", amount_paid: "2500.00",
    remaining: "0.00",  status: "paid",   due_date: "2026-02-28" },
];

const mockInvoiceDetail = {
  id: 1, billing_month: "2026-03-01", amount: "2500.00",
  amount_paid: "0.00", remaining: "2500.00", status: "unpaid",
  due_date: "2026-03-31",
  line_items: [
    { id: 1, item_type: "rent",    description: "Base Rent",    amount: "2500.00" },
    { id: 2, item_type: "discount",description: "Discount",     amount: "-125.00" },
  ],
};

function renderPage() {
  return render(
    <BrowserRouter>
      <AuthProvider>
        <MyInvoices />
      </AuthProvider>
    </BrowserRouter>,
  );
}

describe("TC-11: My Invoices page", () => {
  beforeEach(() => {
    localStorage.setItem("rems_user", JSON.stringify({ role: "tenant", name: "Tenant User" }));
    localStorage.setItem("rems_token", "test-token");
    vi.spyOn(leasesApi, "getLeases").mockResolvedValue({ data: [] });
    vi.spyOn(lettersApi, "getLetters").mockResolvedValue({ data: [] });
    vi.spyOn(lettersApi, "signLetter").mockResolvedValue({ data: {} });
    vi.spyOn(invoicesApi, "getInvoices").mockResolvedValue({ data: mockInvoices });
  });

  afterEach(() => {
    localStorage.clear();
  });

  test("renders page heading", async () => {
    renderPage();
    await waitFor(() => {
      expect(screen.getByRole("heading", { name: /my leases/i })).toBeInTheDocument();
    });
  });

  test("displays list of invoices after loading", async () => {
    renderPage();
    await waitFor(() => {
      expect(screen.getByText(/#1/i)).toBeInTheDocument();
      expect(screen.getByText(/#2/i)).toBeInTheDocument();
    });
  });

  test("shows 'Pay Now' for unpaid invoices and 'View' for paid", async () => {
    renderPage();
    await waitFor(() => {
      expect(screen.getByRole("button", { name: /pay now/i })).toBeInTheDocument();
      expect(screen.getByRole("button", { name: /^view$/i })).toBeInTheDocument();
    });
  });

  test("opens invoice detail modal with line items when Pay Now is clicked", async () => {
    vi.spyOn(invoicesApi, "getInvoice").mockResolvedValueOnce({ data: mockInvoiceDetail });

    renderPage();

    await waitFor(() => screen.getByRole("button", { name: /pay now/i }));
    fireEvent.click(screen.getByRole("button", { name: /pay now/i }));

    await waitFor(() => {
      expect(screen.getByText(/invoice #1/i)).toBeInTheDocument();
      expect(screen.getByText(/base rent/i)).toBeInTheDocument();
      expect(screen.getByText(/discount/i)).toBeInTheDocument();
      expect(screen.getByRole("button", { name: /confirm payment/i })).toBeInTheDocument();
    });
  });

  test("shows payment success message after confirming payment", async () => {
    vi.spyOn(invoicesApi, "getInvoice").mockResolvedValueOnce({ data: mockInvoiceDetail });
    vi.spyOn(paymentsApi, "createPayment").mockResolvedValueOnce({
      data: { invoice_status: "partially_paid" },
    });
    vi.spyOn(invoicesApi, "getInvoices").mockResolvedValue({ data: mockInvoices });

    renderPage();

    await waitFor(() => screen.getByRole("button", { name: /pay now/i }));
    fireEvent.click(screen.getByRole("button", { name: /pay now/i }));

    await waitFor(() => screen.getByRole("button", { name: /confirm payment/i }));

    const payInput = screen.getByPlaceholderText(/2500/i);
    fireEvent.change(payInput, { target: { value: "1000" } });
    fireEvent.click(screen.getByRole("button", { name: /confirm payment/i }));

    await waitFor(() => {
      expect(screen.getByText(/payment of \$1000 recorded/i)).toBeInTheDocument();
    });
  });
});
