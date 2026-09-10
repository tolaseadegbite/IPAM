class CardActivity < ApplicationRecord
  belongs_to :card
  belongs_to :user, optional: true # nil = System (scanner, seeds, triage)

  enum :action, {
    created: 0,
    edited: 1,
    reprioritized: 2,
    moved: 3,
    assigned: 4,
    unassigned: 5,
    linked: 6
  }

  validates :action, presence: true

  scope :recent, -> { order("card_activities.created_at DESC") }

  # Append-only: the timeline is history, never edited in place.
  def readonly?
    persisted?
  end

  def actor_name
    user&.username || "System"
  end
end
