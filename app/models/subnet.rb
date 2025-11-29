class Subnet < ApplicationRecord
  #   has_paper_trail

  has_many :ip_addresses, dependent: :destroy

  validates :name, presence: true
  validates :network_address, presence: true, uniqueness: true

  # Custom validation to ensure it's a valid CIDR (e.g., 192.168.13.0/24)
  validate :valid_cidr_format

  def self.ransackable_attributes(auth_object = nil)
    %w[ id name gateway network_address vlan_id created_at updated_at ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "ip_addresses" ]
  end

  private

  def valid_cidr_format
    IPAddr.new(network_address.to_s)
  rescue IPAddr::InvalidAddressError
    errors.add(:network_address, "is not a valid CIDR range")
  end
end
