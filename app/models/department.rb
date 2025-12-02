class Department < ApplicationRecord
  # has_paper_trail

  NAMES = [
    "Pallet Generation (Generating)",
    "Pallet Generation (Receiving)",
    "Quality Lab",
    "Store",
    "Safety Engineer Office",
    "PM Office",
    "IT Office",
    "HRM Office",
    "Security Post",
    "Reception"
  ].freeze

  belongs_to :branch
  has_many :employees, dependent: :restrict_with_error # Don't delete dept if people are in it
  has_many :devices, dependent: :restrict_with_error

  validates :name, presence: true
  validates :name, inclusion: { in: NAMES, message: "%{value} is not a valid department name" }
  validates :name, uniqueness: { scope: :branch_id, message: "already exists in this branch" }

  def self.ransackable_attributes(auth_object = nil)
    %w[ id name branch created_at updated_at ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "branch", "devices", "employees" ]
  end
end
