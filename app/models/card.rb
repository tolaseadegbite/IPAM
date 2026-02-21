class Card < ApplicationRecord
  belongs_to :list, touch: true

  # Polymorphic link to Device or IpAddress
  belongs_to :referenceable, polymorphic: true, optional: true

  has_many :assignments, dependent: :destroy
  has_many :users, through: :assignments

  # This card's position within the List
  acts_as_list scope: :list

  enum :priority, { low: 0, medium: 1, high: 2 }, default: :low, suffix: true

  validates :title, presence: true
end
