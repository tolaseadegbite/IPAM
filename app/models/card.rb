class Card < ApplicationRecord
  has_paper_trail

  belongs_to :list, touch: true

  # Polymorphic link to Device or IpAddress
  belongs_to :referenceable, polymorphic: true, optional: true

  has_many :assignments, dependent: :delete_all # Join rows only: no callbacks, so card teardown records no phantom unassign events
  has_many :users, through: :assignments

  has_many :activities, class_name: "CardActivity", dependent: :destroy

  # This card's position within the List
  acts_as_list scope: :list

  enum :priority, { low: 0, medium: 1, high: 2 }, default: :low, suffix: true

  validates :title, presence: true

  after_create :record_created_activity
  after_update :record_update_activities

  # Whitelist attributes for searching
  def self.ransackable_attributes(auth_object = nil)
    %w[title description priority created_at]
  end

  # Whitelist associations for searching
  # 'users' allows searching by assignee
  # 'referenceable' allows searching the linked Device/IP
  def self.ransackable_associations(auth_object = nil)
    %w[users list referenceable]
  end

  private

  # Whoever triggered this save (nil outside requests: console, seeds,
  # scanner) is recorded as System at read time.
  def activity_actor
    Current.user
  end

  def record_created_activity
    activities.create!(
      user: activity_actor,
      action: :created,
      metadata: {
        task_title: title,
        priority: priority,
        list: list.name,
        asset: referenceable_label
      }.compact
    )
  end

  # One row per meaningful change. Pure position reshuffles (acts_as_list
  # shifting siblings) intentionally record nothing.
  def record_update_activities
    if saved_change_to_list_id?
      from = List.find_by(id: list_id_before_last_save)&.name
      activities.create!(
        user: activity_actor,
        action: :moved,
        metadata: { task_title: title, from_list: from, to_list: list.name }.compact
      )
    end

    if saved_change_to_priority?
      from, _to = saved_change_to_priority
      from_name = Card.priorities.key(from)&.humanize || from.to_s.humanize
      activities.create!(
        user: activity_actor,
        action: :reprioritized,
        metadata: { task_title: title, from: from_name, to: priority.humanize }
      )
    end

    %w[title description notes].each do |field|
      next unless saved_change_to_attribute?(field)

      from, to = saved_change_to_attribute(field)
      activities.create!(
        user: activity_actor,
        action: :edited,
        metadata: { task_title: title, field: field.humanize, from: from.to_s.truncate(120), to: to.to_s.truncate(120) }
      )
    end

    if saved_change_to_referenceable_type? || saved_change_to_referenceable_id?
      activities.create!(
        user: activity_actor,
        action: :linked,
        metadata: { task_title: title, asset: referenceable_label }.compact
      )
    end
  end

  def referenceable_label
    return nil unless referenceable

    referenceable.respond_to?(:name) ? referenceable.name : referenceable.address.to_s
  end
end
