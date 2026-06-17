class IpAddress < ApplicationRecord
  has_paper_trail ignore: [ :last_seen_at, :updated_at, :created_at, :reachability_status ]

  include PgSearch::Model

  # Search by the IP string itself
  multisearchable against: [ :address ]

  before_validation :enforce_status_consistency

  # Associations
  belongs_to :subnet, counter_cache: true
  belongs_to :device, optional: true

  # Enable linking tasks to IPs (e.g., "Investigate Rogue IP")
  has_many :cards, as: :referenceable, dependent: :nullify

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

  # This returns ONLY rogue devices if true is passed
  scope :rogue_only, ->(boolean = true) {
    return all unless boolean
    where(reachability_status: :up, device_id: nil)
  }

  # Ransack
  def self.ransackable_attributes(auth_object = nil)
    %w[address_string status reachability_status subnet_id created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[device subnet cards]
  end

  def self.ransackable_scopes(auth_object = nil)
    [ :rogue_only ]
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
    # 1. If we unassign a device, make sure the IP is not marked 'active' anymore
    if device_id.nil? && active?
      self.status = :available
    end

    # 2. If we assign a device, make sure the status is not 'available'
    if device_id.present? && available?
      self.status = :active
    end
  end
end
