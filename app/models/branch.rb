class Branch < ApplicationRecord
  has_paper_trail ignore: [ :updated_at, :created_at ]

  has_many :departments, dependent: :restrict_with_error # Don't delete dept if people are in it
  has_many :subnets, dependent: :restrict_with_error # Reassign subnets before deleting the branch
  has_many :devices, through: :departments # Optimization for reporting

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def self.ransackable_attributes(auth_object = nil)
    %w[ id name location contact_phone created_at updated_at ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "departments", "devices", "subnets" ]
  end
end
