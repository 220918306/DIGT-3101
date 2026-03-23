import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { vi } from "vitest";
import { BrowserRouter } from "react-router-dom";
import { AuthProvider } from "../../context/AuthContext";
import ApplicationsList from "./ApplicationsList";
import * as applicationsApi from "../../api/applications";
import * as appointmentsApi from "../../api/appointments";
import * as leasesApi from "../../api/leases";

vi.mock("../../api/applications");
vi.mock("../../api/appointments");
vi.mock("../../api/leases");

const mockApplications = [
  { id: 1, unit_id: 5, unit_number: "101", application_date: "2026-03-01",
    status: "pending", application_data: { business_type: "Retail" }, employment_info: "Sole proprietor" },
  { id: 2, unit_id: 6, unit_number: "202", application_date: "2026-03-05",
    status: "approved", application_data: { business_type: "Food" }, employment_info: null },
];

function renderPage() {
  return render(
    <BrowserRouter>
      <AuthProvider>
        <ApplicationsList />
      </AuthProvider>
    </BrowserRouter>,
  );
}

describe("TC-04/TC-25: Applications List page (clerk)", () => {
  beforeEach(() => {
    localStorage.setItem("rems_user", JSON.stringify({ role: "admin", name: "Admin User" }));
    localStorage.setItem("rems_token", "test-token");
    vi.spyOn(applicationsApi, "getApplications").mockResolvedValue({ data: mockApplications });
    vi.spyOn(appointmentsApi, "getAppointments").mockResolvedValue({ data: [] });
    vi.spyOn(appointmentsApi, "updateAppointment").mockResolvedValue({ data: {} });
    vi.spyOn(leasesApi, "getLeases").mockResolvedValue({ data: [] });
    vi.spyOn(leasesApi, "updateLease").mockResolvedValue({ data: {} });
    vi.spyOn(leasesApi, "sendLeaseAgreement").mockResolvedValue({ data: {} });
  });

  afterEach(() => {
    localStorage.clear();
  });

  test("renders heading and filter tabs", async () => {
    renderPage();
    await waitFor(() => {
      expect(screen.getByRole("heading", { name: /tenants/i })).toBeInTheDocument();
    });
    expect(screen.getAllByRole("button", { name: /^pending$/i }).length).toBeGreaterThan(0);
    expect(screen.getAllByRole("button", { name: /^all$/i }).length).toBeGreaterThan(0);
  });

  test("displays applications with unit number and status badge", async () => {
    renderPage();
    await waitFor(() => {
      expect(screen.getByText("101")).toBeInTheDocument();
      expect(screen.getByText("202")).toBeInTheDocument();
      expect(screen.getByText("Retail")).toBeInTheDocument();
    });
  });

  test("shows Approve and Reject buttons only for pending/under_review applications", async () => {
    renderPage();
    await waitFor(() => {
      expect(screen.getByRole("button", { name: /^approve$/i })).toBeInTheDocument();
      expect(screen.getByRole("button", { name: /^reject$/i })).toBeInTheDocument();
    });
    // The approved application (unit 202, business "Food") should NOT show action buttons
    const rows = screen.getAllByRole("row");
    const approvedRow = rows.find((r) => r.textContent.includes("Food"));
    const btnsInApprovedRow = Array.from(approvedRow.querySelectorAll("button"));
    const hasApproveBtn = btnsInApprovedRow.some((b) => b.textContent.trim() === "Approve");
    expect(hasApproveBtn).toBe(false);
  });

  test("opens approve modal with lease details form when Approve is clicked", async () => {
    renderPage();
    await waitFor(() => screen.getByRole("button", { name: /^approve$/i }));
    fireEvent.click(screen.getByRole("button", { name: /^approve$/i }));

    await waitFor(() => {
      expect(screen.getByText(/approve application #1/i)).toBeInTheDocument();
      expect(screen.getByRole("button", { name: /approve & create lease/i })).toBeInTheDocument();
    });
  });

  test("shows success message after approving application", async () => {
    vi.spyOn(applicationsApi, "approveApplication").mockResolvedValueOnce({
      data: { id: 1, status: "approved" },
    });

    renderPage();
    await waitFor(() => screen.getByRole("button", { name: /^approve$/i }));
    fireEvent.click(screen.getByRole("button", { name: /^approve$/i }));

    await waitFor(() => screen.getByRole("button", { name: /approve & create lease/i }));
    fireEvent.click(screen.getByRole("button", { name: /approve & create lease/i }));

    await waitFor(() => {
      expect(screen.getByText(/application #1 approved/i)).toBeInTheDocument();
    });
  });

  test("reject action is available for pending applications", async () => {
    renderPage();
    await waitFor(() => screen.getByRole("button", { name: /^reject$/i }));
    expect(screen.getByRole("button", { name: /^reject$/i })).toBeInTheDocument();
  });

  test("shows success message after rejecting application", async () => {
    vi.spyOn(applicationsApi, "rejectApplication").mockResolvedValueOnce({
      data: { id: 1, status: "rejected" },
    });

    renderPage();
    await waitFor(() => screen.getByRole("button", { name: /^reject$/i }));
    fireEvent.click(screen.getByRole("button", { name: /^reject$/i }));

    await waitFor(() => {
      expect(screen.getByText(/application #1 rejected/i)).toBeInTheDocument();
    });
  });
});
