require "test_helper"

class UserTest < ActiveSupport::TestCase
  # TC-13: Valid user saves successfully
  test "TC-13: valid user saves with all required attributes" do
    user = User.new(email: "valid@rems.com", name: "Valid User", password: "password123", role: "tenant")
    assert user.valid?, "User with valid attributes should be valid"
    assert user.save
  end

  # TC-14: Email uniqueness is enforced
  test "TC-14: duplicate email is rejected" do
    User.create!(email: "dup@rems.com", name: "First User", password: "password123", role: "tenant")
    duplicate = User.new(email: "dup@rems.com", name: "Second User", password: "password123", role: "tenant")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  # TC-15: Invalid email format is rejected
  test "TC-15: invalid email format is rejected" do
    user = User.new(email: "not-an-email", name: "Test", password: "password123", role: "tenant")
    assert_not user.valid?
    assert user.errors[:email].any?
  end

  # TC-16: BCrypt password authentication works
  test "TC-16: password authentication succeeds with correct password" do
    user = User.create!(email: "auth@rems.com", name: "Auth User", password: "secret123", role: "tenant")
    assert user.authenticate("secret123"),  "Correct password should authenticate"
    assert_not user.authenticate("wrong"),  "Wrong password should fail"
  end

  # TC-17: Role enum validates allowed values
  test "TC-17: role must be tenant clerk or admin" do
    assert_raises(ArgumentError) do
      User.new(role: "superuser")
    end
  end
end
