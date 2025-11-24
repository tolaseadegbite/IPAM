class Branch < ApplicationRecord
#   has_paper_trail

  has_many :departments, dependent: :destroy
  has_many :devices, through: :departments # Optimization for reporting

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :location, presence: true
end