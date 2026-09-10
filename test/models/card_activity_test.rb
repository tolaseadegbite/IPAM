require "test_helper"

class CardActivityTest < ActiveSupport::TestCase
  setup do
    @card = cards(:one)
  end

  test "should be immutable once persisted" do
    activity = @card.activities.create!(action: :edited, metadata: { task_title: @card.title })

    assert activity.persisted?
    assert activity.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { activity.update!(metadata: {}) }
  end

  test "should fall back to System actor without a user" do
    activity = @card.activities.create!(action: :moved, metadata: {})

    assert_nil activity.user
    assert_equal "System", activity.actor_name
  end

  test "should order recent first" do
    first = @card.activities.create!(action: :edited, metadata: {}, created_at: 2.days.ago)
    second = @card.activities.create!(action: :moved, metadata: {}, created_at: 1.day.ago)

    assert_equal [ second.id, first.id ], @card.activities.recent.ids
  end
end
