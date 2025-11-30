class IpAddress < ApplicationRecord
  # has_paper_trail

  belongs_to :subnet
  belongs_to :device, optional: true

  enum :status, { available: 0, active: 1, reserved: 2, blacklisted: 3 }

  validates :address, presence: true, uniqueness: true
  validate :address_within_subnet_range

  scope :free, -> { where(device_id: nil, status: :available) }

  def self.ransackable_attributes(auth_object = nil)
    %w[address created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[device subnet]
  end

  private

  def address_within_subnet_range
    return if address.blank? || subnet.blank?

    # FIX: Use the object directly. Rails has already converted it to IPAddr.
    unless subnet.network_address.include?(address)
      errors.add(:address, "does not belong to the selected Subnet range")
    end
  end
end
