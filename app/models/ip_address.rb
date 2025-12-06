class IpAddress < ApplicationRecord
  # has_paper_trail

  include PgSearch::Model

  # Search by the IP string itself
  multisearchable against: [ :address ]

  before_validation :enforce_status_consistency

  # Associations
  belongs_to :subnet
  belongs_to :device, optional: true

  # Enums
  enum :status, { available: 0, active: 1, reserved: 2, blacklisted: 3 }
  enum :reachability_status, { unknown: 0, up: 1, down: 2 }, prefix: true

  def mark_seen!
    update!(reachability_status: :up, last_seen_at: Time.current)
  end

  # Validations
  validates :address, presence: true, uniqueness: true
  validate :address_within_subnet_range
  validate :cannot_assign_device_if_blacklisted

  # Scopes
  scope :free, -> { where(device_id: nil, status: :available) }

  # Custom Ransacker to convert INET to TEXT for searching
  ransacker :address_string do
    Arel.sql("host(address)")
  end

  # Ransack
  def self.ransackable_attributes(auth_object = nil)
    %w[address_string status subnet_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[device subnet]
  end

  private

  def cannot_assign_device_if_blacklisted
    if blacklisted? && device_id.present?
      errors.add(:status, "is Blacklisted. You must change the status to 'Active' or 'Reserved' before assigning a device.")
    end
  end

  def address_within_subnet_range
    return if address.blank? || subnet.blank?
    unless subnet.network_address.include?(address)
      errors.add(:address, "does not belong to the selected Subnet range")
    end
  end

  def enforce_status_consistency
    # 1. RELEASE IP (Intentional Status Change)
    # If you explicitly change status to 'available' or 'blacklisted',
    # we assume you want to kick the device off immediately.
    # Since this runs before_validation, the device becomes nil, and the validation passes.
    if (available? || blacklisted?) && status_changed?
      self.device = nil
    end

    # 2. ASSIGN IP (Intentional Device Change)
    # If you select a device, we assume you want the IP to be 'active'.
    # We check device_id_changed? so we don't accidentally flip existing 'reserved' IPs.
    if device_id.present? && device_id_changed? && available?
      self.status = :active
    end

    # 3. ORPHAN CHECK (Cleanup)
    # If for any reason there is no device (and it's active), make it available.
    if device_id.nil? && active?
      self.status = :available
    end
  end
end
