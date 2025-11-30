class Subnet < ApplicationRecord
  # has_paper_trail
  has_many :ip_addresses, dependent: :destroy

  validates :name, presence: true
  validates :network_address, presence: true, uniqueness: true
  validates :gateway, presence: true

  validate :valid_cidr_format
  validate :gateway_must_be_within_subnet
  validate :network_ranges_must_not_overlap

  after_create :populate_ip_addresses

  def self.ransackable_attributes(auth_object = nil)
    %w[ id name gateway network_address vlan_id created_at updated_at ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "ip_addresses" ]
  end

  private

  def valid_cidr_format
    # Rails usually handles this casting automatically.
    # If casting fails, network_address might be nil.
    # We check the raw string just to be sure.
    raw_addr = network_address_before_type_cast
    return if raw_addr.blank?

    IPAddr.new(raw_addr.to_s)
  rescue IPAddr::InvalidAddressError
    errors.add(:network_address, "is not a valid CIDR range")
  end

  def gateway_must_be_within_subnet
    return if network_address.blank? || gateway.blank?

    # FIX: Use the objects directly. Do NOT convert to_s and back.
    # 'network_address' and 'gateway' are already IPAddr objects thanks to Rails.

    unless network_address.include?(gateway)
      errors.add(:gateway, "must be within the #{network_address} range")
    end

    # Ensure Gateway is not the Network ID or Broadcast Address
    range = network_address.to_range
    if gateway == range.first
      errors.add(:gateway, "cannot be the Network ID address (first IP)")
    elsif gateway == range.last
      errors.add(:gateway, "cannot be the Broadcast address (last IP)")
    end
  end

  def network_ranges_must_not_overlap
    return if network_address.blank?

    # Use raw string for PostgreSQL query
    cidr_string = network_address_before_type_cast

    query = Subnet.where.not(id: id)
                  .where("network_address && ?", cidr_string)

    if query.exists?
      overlapping_subnet = query.first
      errors.add(:network_address, "overlaps with existing subnet: #{overlapping_subnet.name} (#{overlapping_subnet.network_address})")
    end
  end

  def populate_ip_addresses
    # Use the IPAddr object directly to get the range
    cidr = network_address
    all_ips = cidr.to_range.to_a
    return if all_ips.size < 3

    host_ips = all_ips[1...-1]

    now = Time.current
    ip_data = host_ips.map do |ip|
      {
        address: ip.to_s,
        subnet_id: id,
        status: 0,
        created_at: now,
        updated_at: now
      }
    end

    IpAddress.insert_all(ip_data)
  rescue => e
    Rails.logger.error("IP Population Failed for Subnet #{id}: #{e.message}")
  end
end
