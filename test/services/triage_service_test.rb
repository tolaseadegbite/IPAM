require "test_helper"

class TriageServiceTest < ActiveSupport::TestCase
  setup do
    @device = devices(:one)
  end

  test "security event opens a high-priority card linked to the asset" do
    event = NetworkEvent.create!(
      kind: :security,
      ip_address: "10.0.9.9",
      device: @device,
      message: "Unknown MAC seized IP."
    )

    assert_difference("Card.count", 1) do
      @card = TriageService.triage(event)
    end

    assert_equal "high", @card.priority
    assert_equal @device, @card.referenceable
    assert_equal "To Do", @card.list.name
    assert_equal "Network Triage", @card.list.board.name
  end

  test "drift event opens a medium-priority card" do
    event = NetworkEvent.create!(kind: :drift, ip_address: "10.0.9.8", message: "Moved.")

    card = TriageService.triage(event)

    assert_equal "medium", card.priority
  end

  test "info event opens nothing" do
    event = NetworkEvent.create!(kind: :info, ip_address: "10.0.9.7", message: "Noted.")

    assert_no_difference("Card.count") do
      assert_nil TriageService.triage(event)
    end
  end

  test "flapping host does not open duplicate cards" do
    event = NetworkEvent.create!(
      kind: :security, ip_address: "10.0.9.9", device: @device, message: "Seized."
    )
    TriageService.triage(event)

    again = NetworkEvent.create!(
      kind: :security, ip_address: "10.0.9.9", device: @device, message: "Seized again."
    )

    assert_no_difference("Card.count") do
      assert_nil TriageService.triage(again)
    end
  end

  test "resolving the card allows a new card for a repeat event" do
    event = NetworkEvent.create!(
      kind: :security, ip_address: "10.0.9.9", device: @device, message: "Seized."
    )
    card = TriageService.triage(event)
    done = card.list.board.lists.find_by!(name: "Done")
    card.update!(list: done)

    repeat = NetworkEvent.create!(
      kind: :security, ip_address: "10.0.9.9", device: @device, message: "Seized again."
    )

    assert_difference("Card.count", 1) do
      TriageService.triage(repeat)
    end
  end

  test "ensure_board! is idempotent" do
    first = TriageService.ensure_board!
    second = TriageService.ensure_board!

    assert_equal first.id, second.id
    assert_equal %w[Doing Done To\ Do].sort, first.lists.pluck(:name).sort
  end
end
