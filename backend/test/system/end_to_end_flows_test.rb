require "application_system_test_case"

class EndToEndFlowsTest < ApplicationSystemTestCase
  # Basic happy-path smoke tests to back the high-level use cases in the report.

  test "tenant signs in and views units" do
    tenant_user = FactoryBot.create(:user, :tenant, email: "tenant@example.com", password: "password123")
    FactoryBot.create(:tenant, user: tenant_user)

    visit "/login"
    fill_in "Email address", with: "tenant@example.com"
    fill_in "Password", with: "password123"
    click_on "Sign In"

    assert_text "Available Units"
  end
end

