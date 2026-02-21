class Board < ApplicationRecord
  has_many :lists, -> { order(position: :asc) }, dependent: :destroy
  has_many :cards, through: :lists

  validates :name, presence: true

  # NEW: When this board's updated_at changes, tell all viewers to refresh smoothly
  broadcasts_refreshes
end
