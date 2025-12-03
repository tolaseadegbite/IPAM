class Department < ApplicationRecord
  # has_paper_trail

  NAMES = [
    "Account",
    "DHRM",
    "Engineer Office",
    "Factory Manager",
    "HRM",
    "IT Office",
    "Marketing",
    "PM Office",
    "Pallet Generation (Generating)",
    "Pallet Generation (Receiving)",
    "Personnel Manager Office",
    "Personnel Office",
    "Quality Lab",
    "Reception",
    "Safety Engineer Office",
    "Secretary",
    "Security Post",
    "Store",
    "Waybill Office",
    "Weight Bridge"
  ].freeze

  belongs_to :branch
  has_many :employees, dependent: :restrict_with_error
  has_many :devices, dependent: :restrict_with_error

  validates :name, presence: true
  validates :name, inclusion: { in: NAMES, message: "%{value} is not a valid department name" }
  validates :name, uniqueness: { scope: :branch_id, message: "already exists in this branch" }

  def self.ransackable_attributes(auth_object = nil)
    %w[ id name branch_id created_at updated_at ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "branch", "devices", "employees" ]
  end
end
