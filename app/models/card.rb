class Card < ApplicationRecord
  has_paper_trail

  belongs_to :list, touch: true

  # Polymorphic link to Device or IpAddress
  belongs_to :referenceable, polymorphic: true, optional: true

  has_many :assignments, dependent: :destroy
  has_many :users, through: :assignments

  # This card's position within the List
  acts_as_list scope: :list

  enum :priority, { low: 0, medium: 1, high: 2 }, default: :low, suffix: true

  validates :title, presence: true

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
end
