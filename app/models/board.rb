class Board < ApplicationRecord
  has_many :lists, -> { order(position: :asc) }, dependent: :destroy
  has_many :cards, through: :lists

  validates :name, presence: true
end
