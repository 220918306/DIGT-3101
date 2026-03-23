import { render, screen, waitFor, fireEvent } from "@testing-library/react";
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

  test("TC-16: Search sends min_price and max_price to the units API", async () => {
    const mockUnits = [
      { id: 1, unit_number: "101", size: 500, rental_rate: 1500, status: "available", tier: "standard", purpose: "retail" },
      { id: 2, unit_number: "102", size: 750, rental_rate: 1800, status: "available", tier: "premium", purpose: "food" },
    ];
    const getUnitsSpy = vi.spyOn(unitsApi, "getUnits").mockResolvedValue({ data: mockUnits });

    renderPage();

    await waitFor(() => {
      expect(screen.getByText(/Unit 101/i)).toBeInTheDocument();
    });

    fireEvent.change(screen.getByPlaceholderText("$0"), { target: { value: "1000" } });
    fireEvent.change(screen.getByPlaceholderText("$10,000"), { target: { value: "2000" } });
    fireEvent.click(screen.getByRole("button", { name: /search/i }));

    await waitFor(() => {
      expect(getUnitsSpy).toHaveBeenLastCalledWith(
        expect.objectContaining({
          min_price: "1000",
          max_price: "2000",
        }),
      );
    });
  });
});

