class IpAddress < ApplicationRecord
  # has_paper_trail

  # Callbacks
  before_save :enforce_status_consistency

  # Associations
  belongs_to :subnet
  belongs_to :device, optional: true

  # Enums
  enum :status, { available: 0, active: 1, reserved: 2, blacklisted: 3 }

  # Validations
  validates :address, presence: true, uniqueness: true
  validate :address_within_subnet_range

  # Scopes
  scope :free, -> { where(device_id: nil, status: :available) }

  # Ransack
  def self.ransackable_attributes(auth_object = nil)
    %w[address created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[device subnet]
  end

  private

  def address_within_subnet_range
    return if address.blank? || subnet.blank?
    unless subnet.network_address.include?(address)
      errors.add(:address, "does not belong to the selected Subnet range")
    end
  end

  # Smart logic to handle dual-intent
  def enforce_status_consistency
    # 1. USER INTENT: RELEASE IP
    # If the user explicitly changed status to 'available' or 'blacklisted',
    # we assume they want to disconnect the device, even if the device_id is still present in the form data.
    if (available? || blacklisted?) && status_changed?
      self.device = nil
    end

    # 2. USER INTENT: ASSIGN DEVICE
    # If the user explicitly changed/added a device,
    # we assume they want the IP to be 'active', even if they forgot to change the status from 'available'.
    if device_id.present? && device_id_changed? && available?
      self.status = :active
    end

    # 3. CLEANUP: ORPHAN CHECK
    # If for any reason there is no device (and it's not reserved/blacklisted),
    # it shouldn't be marked as 'active'.
    if device_id.nil? && active?
      self.status = :available
    end

    # 4. SAFETY: HARD RULE
    # Blacklisted IPs can never have a device, no matter what.
    if blacklisted?
      self.device = nil
    end
  end
end
