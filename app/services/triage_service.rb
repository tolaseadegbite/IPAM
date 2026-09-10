# Turns severe network events into triaged kanban cards.
#
# Policy: security/outage -> high priority, drift -> medium, info -> nothing.
# Deduplicates against open cards (anything outside a Done list) so a
# flapping host opens exactly one card until it is resolved.
class TriageService
  BOARD_NAME = "Network Triage"
  TODO_LIST_NAME = "To Do"

  PRIORITY_BY_KIND = {
    "security" => :high,
    "outage" => :high,
    "drift" => :medium
  }.freeze

  def self.triage(event)
    new(event).triage
  end

  # Finds the triage board, creating it (with To Do/Doing/Done) on first use.
  def self.ensure_board!
    Board.find_or_create_by!(name: BOARD_NAME) do |board|
      board.description = "Auto-filed network investigations. Created on demand."
    end.tap do |board|
      [ "To Do", "Doing", "Done" ].each do |list_name|
        board.lists.find_or_create_by!(name: list_name)
      end
    end
  end

  def initialize(event)
    @event = event
  end

  def triage
    priority = PRIORITY_BY_KIND[@event.kind]
    return nil if priority.nil?

    notify_admins

    return nil if open_card_exists?

    Card.create!(
      title: title,
      description: description,
      priority: priority,
      list: todo_list,
      referenceable: asset
    )
  end

  # Fan-out to admins with flap protection: one unread notification per
  # asset until it is read, independent of the card dedup above.
  def notify_admins
    User.where(admin: true).find_each do |admin|
      next if asset && unread_notification_exists?(admin)

      SecurityEventNotifier.with(
        record: asset,
        message: "#{title} — #{@event.message}",
        kind: @event.kind
      ).deliver(admin)
    end
  end

  def unread_notification_exists?(admin)
    admin.notifications.unread
         .where(type: "SecurityEventNotifier::Notification")
         .joins(:event)
         .where(noticed_events: { record_type: asset.class.name, record_id: asset.id })
         .exists?
  end

  private

  def todo_list
    self.class.ensure_board!.lists.find_by!(name: TODO_LIST_NAME)
  end

  def asset
    @asset ||= @event.device || IpAddress.find_by(address: @event.ip_address.to_s)
  end

  def title
    @title ||= case @event.kind
    when "security" then "Investigate security event at #{@event.ip_address}"
    when "outage" then "Investigate outage at #{@event.ip_address}"
    when "drift" then "Device moved: #{@event.device&.name} claimed #{@event.ip_address}"
    end
  end

  def description
    @description ||= "#{@event.message} (Detected #{@event.created_at.strftime("%b %d, %H:%M")})"
  end

  def open_card_exists?
    scope = Card.joins(:list).where("lists.name NOT ILIKE ?", "done")
    if asset
      scope = scope.where(referenceable_type: asset.class.name, referenceable_id: asset.id)
    else
      scope = scope.where(title: title)
    end
    scope.exists?
  end
end
