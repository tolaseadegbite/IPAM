class IpAddress < ApplicationRecord
  # has_paper_trail

  belongs_to :subnet
  belongs_to :device, optional: true # Null = Unused/Available

  enum :status, { available: 0, active: 1, reserved: 2, blacklisted: 3 }

  # The IP itself (e.g., 192.168.13.55)
  validates :address, presence: true, uniqueness: true
  
  # Logic validation: Ensure the IP actually belongs to the parent Subnet
  validate :address_within_subnet_range

  # Scopes for performance
  scope :free, -> { where(device_id: nil, status: :available) }

  private
  def address_within_subnet_range
    return if address.blank? || subnet.blank?
    unless IPAddr.new(subnet.network_address).include?(address)
      errors.add(:address, "does not belong to the selected Subnet range")
    end
  end
end