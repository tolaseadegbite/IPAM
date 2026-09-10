require "test_helper"

class AssignmentTest < ActiveSupport::TestCase
  test "should reject duplicate user on same card" do
    existing = assignments(:one)

    dupe = Assignment.new(user: existing.user, card: existing.card)
    assert_not dupe.valid?
    assert_includes dupe.errors[:user_id], "has already been taken"
  end

  test "should allow same user on different cards" do
    other_user = User.create!(username: "tech_two", email: "tech_two@example.com",
      password: "Secret1*3*5*", verified: true)

    other = Assignment.new(user: other_user, card: cards(:two))
    assert other.valid?
  end
end
