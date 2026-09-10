class BackfillCardActivities < ActiveRecord::Migration[8.1]
  # Frozen stand-ins so future model changes can never break this replay.
  class BackfillCard < ApplicationRecord
    self.table_name = "cards"
  end

  class BackfillList < ApplicationRecord
    self.table_name = "lists"
  end

  class BackfillUser < ApplicationRecord
    self.table_name = "users"
  end

  class BackfillActivity < ApplicationRecord
    self.table_name = "card_activities"
  end

  PRIORITY_NAMES = { 0 => "Low", 1 => "Medium", 2 => "High" }.freeze
  TRACKED_EDITS = %w[title description notes].freeze

  def up
    say_with_time "Backfilling card activities from PaperTrail versions" do
      created = 0
      PaperTrail::Version.where(item_type: "Card").order(:created_at).find_each do |version|
        created += backfill_version(version)
      end
      created
    end
  end

  def down
    # Keep replayed rows: history continuity beats reversibility here.
  end

  private

  def backfill_version(version)
    card = BackfillCard.find_by(id: version.item_id)
    return 0 if card.nil? # card since deleted; global audit keeps the trace

    user_id = version.whodunnit.to_s.match?(/\A\d+\z/) ? version.whodunnit.to_i : nil
    user_id = nil unless BackfillUser.exists?(user_id) if user_id
    at = version.created_at
    rows = 0

    case version.event
    when "create"
      changes = version.changeset
      rows += insert_activity(card, user_id, 0, {
        task_title: change_value(changes["title"], card["title"]),
        priority: PRIORITY_NAMES.fetch(change_value(changes["priority"], card["priority"]).to_i, "Low"),
        list: list_name(change_value(changes["list_id"], card["list_id"]))
      }, at)
    when "update"
      changes = version.changeset
      if changes["list_id"] && changes["list_id"].first != changes["list_id"].last
        rows += insert_activity(card, user_id, 3, {
          task_title: card["title"],
          from_list: list_name(changes["list_id"].first),
          to_list: list_name(changes["list_id"].last)
        }, at)
      end
      if changes["priority"] && changes["priority"].first != changes["priority"].last
        rows += insert_activity(card, user_id, 2, {
          task_title: card["title"],
          from: PRIORITY_NAMES.fetch(changes["priority"].first.to_i, "?"),
          to: PRIORITY_NAMES.fetch(changes["priority"].last.to_i, "?")
        }, at)
      end
      TRACKED_EDITS.each do |field|
        next unless changes[field] && changes[field].first.to_s != changes[field].last.to_s

        rows += insert_activity(card, user_id, 1, {
          task_title: card["title"],
          field: field.humanize,
          from: changes[field].first.to_s.truncate(120),
          to: changes[field].last.to_s.truncate(120)
        }, at)
      end
    end
    rows
  end

  def insert_activity(card, user_id, action, metadata, at)
    BackfillActivity.create!(
      card_id: card.id, user_id: user_id, action: action,
      metadata: metadata.compact, created_at: at, updated_at: at
    )
    1
  end

  def change_value(change, fallback)
    change ? change.last : fallback
  end

  def list_name(id)
    BackfillList.find_by(id: id)&.name
  end
end
