import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { vi } from "vitest";
import { BrowserRouter } from "react-router-dom";
import { AuthProvider } from "../../context/AuthContext";
import MaintenanceQueue from "./MaintenanceQueue";
import * as maintenanceApi from "../../api/maintenance";

vi.mock("../../api/maintenance");

const mockTickets = [
  { id: 1, description: "Gas leak near stove",    priority: "emergency", status: "open",
    unit_id: 5, is_tenant_caused: false, created_at: new Date().toISOString() },
  { id: 2, description: "HVAC making noise",      priority: "urgent",    status: "open",
    unit_id: 6, is_tenant_caused: false, created_at: new Date().toISOString() },
  { id: 3, description: "Light bulb replacement", priority: "routine",   status: "in_progress",
    unit_id: 7, is_tenant_caused: true,  created_at: new Date().toISOString() },
];

function renderPage() {
  return render(
    <BrowserRouter>
      <AuthProvider>
        <MaintenanceQueue />
      </AuthProvider>
    </BrowserRouter>,
  );
}

describe("TC-23: Maintenance Queue page (clerk)", () => {
  beforeEach(() => {
    vi.spyOn(maintenanceApi, "getTickets").mockResolvedValue({ data: mockTickets });
  });

  test("renders page heading with priority order explanation", async () => {
    renderPage();
    await waitFor(() => {
      expect(screen.getByRole("heading", { name: /maintenance queue/i })).toBeInTheDocument();
    });
    expect(screen.getByText(/emergency.*urgent.*routine/i)).toBeInTheDocument();
  });

  test("displays all tickets with descriptions and priorities", async () => {
    renderPage();
    await waitFor(() => {
      expect(screen.getByText(/gas leak near stove/i)).toBeInTheDocument();
      expect(screen.getByText(/hvac making noise/i)).toBeInTheDocument();
      expect(screen.getByText(/light bulb replacement/i)).toBeInTheDocument();
    });
  });

  test("shows empty state when no tickets exist", async () => {
    vi.spyOn(maintenanceApi, "getTickets").mockResolvedValueOnce({ data: [] });
    renderPage();
    await waitFor(() => {
      expect(screen.getByText(/no active maintenance tickets/i)).toBeInTheDocument();
    });
  });

  test("shows Update button for each ticket", async () => {
    renderPage();
    await waitFor(() => {
      const updateBtns = screen.getAllByRole("button", { name: /update/i });
      expect(updateBtns.length).toBe(3);
    });
  });

  test("opens Update Status modal when Update is clicked", async () => {
    renderPage();
    await waitFor(() => screen.getAllByRole("button", { name: /update/i }));

    fireEvent.click(screen.getAllByRole("button", { name: /update/i })[0]);

    await waitFor(() => {
      expect(screen.getByText(/update ticket #1/i)).toBeInTheDocument();
      expect(screen.getByRole("button", { name: /^save$/i })).toBeInTheDocument();
    });
  });

  test("shows success message after updating ticket status", async () => {
    vi.spyOn(maintenanceApi, "updateTicket").mockResolvedValueOnce({ data: { id: 1, status: "in_progress" } });

    renderPage();
    await waitFor(() => screen.getAllByRole("button", { name: /update/i }));

    fireEvent.click(screen.getAllByRole("button", { name: /update/i })[0]);
    await waitFor(() => screen.getByRole("button", { name: /^save$/i }));

    fireEvent.click(screen.getByRole("button", { name: /^save$/i }));

    await waitFor(() => {
      expect(screen.getByText(/ticket #1 updated/i)).toBeInTheDocument();
    });
  });

  test("shows Bill Damage button only for non-tenant-caused tickets", async () => {
    renderPage();
    await waitFor(() => {
      // Tickets 1 and 2 are not tenant-caused → should have Bill Damage
      const billBtns = screen.getAllByRole("button", { name: /bill damage/i });
      expect(billBtns.length).toBe(2);
    });
  });

  test("opens Bill Damage modal when Bill Damage is clicked", async () => {
    renderPage();
    await waitFor(() => screen.getAllByRole("button", { name: /bill damage/i }));

    fireEvent.click(screen.getAllByRole("button", { name: /bill damage/i })[0]);

    await waitFor(() => {
      expect(screen.getByText(/bill tenant for damage/i)).toBeInTheDocument();
      expect(screen.getByPlaceholderText(/0\.00/i)).toBeInTheDocument();
    });
  });
});
