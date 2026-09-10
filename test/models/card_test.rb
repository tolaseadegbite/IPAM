require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    @card = cards(:one)
    @board = boards(:one)
  end

  test "should record creation" do
    card = nil
    assert_difference "@board.cards.count", 1 do
      assert_difference "CardActivity.count", 1 do
        card = @board.lists.first.cards.create!(title: "Fresh task")
      end
    end

    activity = card.activities.recent.first
    assert_predicate activity, :created?
    assert_equal "Fresh task", activity.metadata["task_title"]
  end

  test "should record rename as edit" do
    assert_difference "@card.activities.count", 1 do
      @card.update!(title: "Renamed task")
    end

    activity = @card.activities.recent.first
    assert_predicate activity, :edited?
    assert_equal "Title", activity.metadata["field"]
  end

  test "should record column move with from and to names" do
    target = @board.lists.create!(name: "Target")

    assert_difference "@card.activities.count", 1 do
      @card.update!(list: target)
    end

    activity = @card.activities.recent.first
    assert_predicate activity, :moved?
    assert_equal lists(:one).name, activity.metadata["from_list"]
    assert_equal "Target", activity.metadata["to_list"]
  end

  test "should record reprioritize with humanized names" do
    @card.update!(priority: :high)

    activity = @card.activities.recent.first
    assert_predicate activity, :reprioritized?
    assert_equal "Medium", activity.metadata["from"]
    assert_equal "High", activity.metadata["to"]
  end

  test "should not record position-only touches" do
    assert_no_difference "@card.activities.count" do
      @card.touch
    end
  end

  test "should record assign and unassign with assignee snapshot" do
    user = User.create!(username: "crew_ops", email: "crew_ops@example.com",
      password: "Secret1*3*5*", verified: true)

    assert_difference "@card.activities.count", 1 do
      @card.users << user
    end
    assert_predicate @card.activities.recent.first, :assigned?
    assert_equal "crew_ops", @card.activities.recent.first.metadata["assignee_name"]

    assert_difference "@card.activities.count", 1 do
      @card.users.destroy(user)
    end
    assert_predicate @card.activities.recent.first, :unassigned?
  end
end
