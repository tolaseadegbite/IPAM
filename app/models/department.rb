class Department < ApplicationRecord
  # has_paper_trail

  belongs_to :branch
  has_many :employees, dependent: :restrict_with_error # Don't delete dept if people are in it
  has_many :devices, dependent: :restrict_with_error

  validates :name, presence: true
  # Scoped Uniqueness: "Safety Office" can exist in "Yale 1" AND "Yale 5", but not twice in "Yale 1"
  validates :name, uniqueness: { scope: :branch_id, case_sensitive: false, message: "already exists in this branch" }
end