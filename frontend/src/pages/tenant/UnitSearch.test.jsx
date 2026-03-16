import { render, screen, waitFor } from "@testing-library/react";
import { vi } from "vitest";
import { BrowserRouter } from "react-router-dom";
import UnitSearch from "./UnitSearch";
import { AuthProvider } from "../../context/AuthContext";
import * as unitsApi from "../../api/units";

vi.mock("../../api/units");

function renderPage() {
  return render(
    <BrowserRouter>
      <AuthProvider>
        <UnitSearch />
      </AuthProvider>
    </BrowserRouter>,
  );
}

describe("UnitSearch page", () => {
  test("loads and displays units from API", async () => {
    const mockUnits = [
      { id: 1, unit_number: "101", size: 500, rental_rate: 2000, status: "available", tier: "standard", purpose: "retail" },
      { id: 2, unit_number: "102", size: 750, rental_rate: 2600, status: "available", tier: "premium", purpose: "food" }
    ];

    vi.spyOn(unitsApi, "getUnits").mockResolvedValueOnce({ data: mockUnits });

    renderPage();

    await waitFor(() => {
      expect(screen.getByText(/Unit 101/i)).toBeInTheDocument();
      expect(screen.getByText(/Unit 102/i)).toBeInTheDocument();
    });
  });
});

