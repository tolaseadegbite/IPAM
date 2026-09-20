# Cursor pagination for chat message history (Campfire-style windows).
# Cursors are message ids: strictly ordered, indexed, and free of the
# same-timestamp ties a created_at cursor would need tiebreakers for.
module MessagePagination
  extend ActiveSupport::Concern

  PAGE_SIZE = 25

  included do
    scope :newest_first, -> { reorder(id: :desc) }
    scope :last_page, -> { newest_first.limit(PAGE_SIZE).to_a.reverse }
    scope :first_page, -> { reorder(id: :asc).limit(PAGE_SIZE).to_a }

    scope :before, ->(message) { where("messages.id < ?", message.id) }
    scope :after, ->(message) { where("messages.id > ?", message.id) }

    scope :page_before, ->(message) { before(message).newest_first.limit(PAGE_SIZE).to_a.reverse }
    scope :page_after, ->(message) { after(message).first_page }
  end
end
