class Branch < ApplicationRecord
  #   has_paper_trail

  has_many :departments, dependent: :restrict_with_error # Don't delete dept if people are in it
  has_many :devices, through: :departments # Optimization for reporting

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  # validates :location, presence: true

  def self.ransackable_attributes(auth_object = nil)
    %w[ id name location contact_phone created_at updated_at ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "departments", "devices" ]
  end
end
