class Assignment < ApplicationRecord
  belongs_to :user
  belongs_to :card

  validates :user_id, uniqueness: { scope: :card_id }

  after_create :record_assigned_activity
  after_destroy :record_unassigned_activity

  private

  def record_assigned_activity
    card.activities.create!(
      user: Current.user,
      action: :assigned,
      metadata: { task_title: card.title, assignee_name: user.username, assignee_id: user.id }
    )
  end

  def record_unassigned_activity
    # Card teardown nullifies nothing here (assignments use delete_all on
    # the card side); guard direct destroys against a vanished card.
    return if card.nil? || card.destroyed?

    card.activities.create!(
      user: Current.user,
      action: :unassigned,
      metadata: { task_title: card.title, assignee_name: user.username, assignee_id: user.id }
    )
  end
end
