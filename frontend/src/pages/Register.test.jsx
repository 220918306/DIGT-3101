import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { vi } from "vitest";
import { BrowserRouter } from "react-router-dom";
import { AuthProvider } from "../context/AuthContext";
import Register from "./Register";
import api from "../api/axios";

vi.mock("../api/axios", () => ({
  default: {
    post: vi.fn(),
    get:  vi.fn(),
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
  },
}));

function renderPage() {
  return render(
    <BrowserRouter>
      <AuthProvider>
        <Register />
      </AuthProvider>
    </BrowserRouter>,
  );
}

describe("TC-02: Register page", () => {
  test("renders all required form fields and submit button", () => {
    renderPage();
    expect(screen.getByPlaceholderText(/alice smith/i)).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/alice@example.com/i)).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/at least 6 characters/i)).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/416-555-0100/i)).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/alice's boutique/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /create account/i })).toBeInTheDocument();
  });

  test("renders Create Account heading and tagline", () => {
    renderPage();
    expect(screen.getByRole("heading", { name: "Create Account" })).toBeInTheDocument();
    expect(screen.getByText(/register as a new tenant/i)).toBeInTheDocument();
  });

  test("shows link to sign in for existing users", () => {
    renderPage();
    expect(screen.getByRole("link", { name: /sign in/i })).toBeInTheDocument();
  });

  test("shows toast listing missing required fields when submit is incomplete", async () => {
    renderPage();
    fireEvent.click(screen.getByRole("button", { name: /create account/i }));
    await waitFor(() => {
      expect(screen.getByRole("alert")).toHaveTextContent(/please fill in:/i);
      expect(screen.getByRole("alert")).toHaveTextContent(/full name/i);
      expect(screen.getByRole("alert")).toHaveTextContent(/email/i);
      expect(screen.getByRole("alert")).toHaveTextContent(/password/i);
      expect(screen.getByRole("alert")).toHaveTextContent(/company name/i);
    });
  });

  test("shows error banner when API returns an error", async () => {
    api.post.mockRejectedValueOnce({
      response: { data: { error: "Email already taken" } },
    });

    renderPage();

    fireEvent.change(screen.getByPlaceholderText(/alice smith/i),       { target: { value: "Alice" } });
    fireEvent.change(screen.getByPlaceholderText(/alice@example.com/i), { target: { value: "alice@test.com" } });
    fireEvent.change(screen.getByPlaceholderText(/at least 6 characters/i), { target: { value: "pass123" } });
    fireEvent.change(screen.getByPlaceholderText(/alice's boutique/i), { target: { value: "Alice Co" } });

    fireEvent.click(screen.getByRole("button", { name: /create account/i }));

    await waitFor(() => {
      expect(screen.getByText(/email already taken/i)).toBeInTheDocument();
    });
  });
});
