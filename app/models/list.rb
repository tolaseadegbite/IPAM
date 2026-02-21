class List < ApplicationRecord
  belongs_to :board, touch: true

  # Determine order of cards within this list
  has_many :cards, -> { order(position: :asc) }, dependent: :destroy

  # This list's position within the Board
  acts_as_list scope: :board

  validates :name, presence: true
end
