import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { vi } from "vitest";
import { BrowserRouter } from "react-router-dom";
import { AuthProvider } from "../../context/AuthContext";
import MaintenanceRequest from "./MaintenanceRequest";
import * as maintenanceApi from "../../api/maintenance";
import * as leasesApi from "../../api/leases";

vi.mock("../../api/maintenance");
vi.mock("../../api/leases");

function renderPage() {
  return render(
    <BrowserRouter>
      <AuthProvider>
        <MaintenanceRequest />
      </AuthProvider>
    </BrowserRouter>,
  );
}

describe("TC-10: Maintenance Request page", () => {
  beforeEach(() => {
    localStorage.setItem("rems_user", JSON.stringify({ role: "tenant", name: "Tenant User" }));
    localStorage.setItem("rems_token", "test-token");
    vi.spyOn(maintenanceApi, "getTickets").mockResolvedValue({ data: [] });
    vi.spyOn(leasesApi, "getLeases").mockResolvedValue({ data: [] });
  });

  afterEach(() => {
    localStorage.clear();
  });

  test("renders the submission form with priority buttons and description textarea", async () => {
    renderPage();
    expect(screen.getByRole("heading", { name: /maintenance requests/i })).toBeInTheDocument();
    expect(screen.getAllByText(/routine/i).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/urgent/i).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/emergency/i).length).toBeGreaterThan(0);
    expect(screen.getByPlaceholderText(/describe the issue/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /submit request/i })).toBeInTheDocument();
  });

  test("shows existing tickets after load", async () => {
    vi.spyOn(maintenanceApi, "getTickets").mockResolvedValue({
      data: [
        { id: 1, description: "Broken door lock", priority: "urgent", status: "open", created_at: new Date().toISOString() },
        { id: 2, description: "Water leak",       priority: "emergency", status: "open", created_at: new Date().toISOString() },
      ],
    });

    renderPage();

    await waitFor(() => {
      expect(screen.getByText(/broken door lock/i)).toBeInTheDocument();
      expect(screen.getByText(/water leak/i)).toBeInTheDocument();
    });
  });

  test("shows success message after ticket is submitted", async () => {
    vi.spyOn(maintenanceApi, "createTicket").mockResolvedValueOnce({ data: { id: 99 } });

    renderPage();

    fireEvent.change(screen.getByPlaceholderText(/describe the issue/i), {
      target: { value: "The AC unit is making loud noises." },
    });

    fireEvent.click(screen.getByRole("button", { name: /submit request/i }));

    await waitFor(() => {
      expect(screen.getByText(/maintenance request submitted/i)).toBeInTheDocument();
    });
  });

  test("shows error message when description is empty on submit", async () => {
    renderPage();

    fireEvent.click(screen.getByRole("button", { name: /submit request/i }));

    await waitFor(() => {
      expect(screen.getByText(/please describe the issue/i)).toBeInTheDocument();
    });
  });

  test("shows error when API call fails", async () => {
    vi.spyOn(maintenanceApi, "createTicket").mockRejectedValueOnce({
      response: { data: { error: "Do you have an active lease?" } },
    });

    renderPage();

    fireEvent.change(screen.getByPlaceholderText(/describe the issue/i), {
      target: { value: "Pipe burst in bathroom" },
    });
    fireEvent.click(screen.getByRole("button", { name: /submit request/i }));

    await waitFor(() => {
      expect(screen.getByText(/do you have an active lease/i)).toBeInTheDocument();
    });
  });
});
