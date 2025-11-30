class Device < ApplicationRecord
  # has_paper_trail

  belongs_to :department
  belongs_to :employee, optional: true # Optional: New laptops might be in storage (no owner)

  # When a device is deleted/retired, the IP is automatically freed (set to null)
  has_one :ip_address, dependent: :nullify

  # Delegations for convenience (e.g., calling @device.branch_name)
  delegate :branch, to: :department
  delegate :name, to: :department, prefix: true

  enum :device_type, { laptop: 0, desktop: 1, all_in_one: 2, printer: 3, server: 4, tablet: 5 }
  enum :status, { active: 0, in_storage: 1, in_repair: 2, retired: 3, lost: 4 }

  validates :serial_number, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true # Hostname
  validates :device_type, presence: true
  validates :status, presence: true

  # Validation to ensure a device doesn't have an IP assigned if it's "Retired"
  validate :ip_released_if_retired

  def self.ransackable_attributes(auth_object = nil)
    %w[ name asset_tag serial_number status created_at updated_at ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "department", "employee", "ip_address" ]
  end

  private

  def ip_released_if_retired
    if retired? && ip_address.present?
      errors.add(:status, "cannot be Retired while holding an IP Address. Release the IP first.")
    end
  end
end
