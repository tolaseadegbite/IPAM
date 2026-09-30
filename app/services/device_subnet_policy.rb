# Single source of truth for which subnet combinations a device may hold.
#
# Rules (estate policy):
# - One series per device: no two IPs from the same subnet.
# - Exclusive pairs: .13 x .30 (alternative user segments), .15 x .16
#   (the two internet legs). A device holds at most one side of each.
# - Max rows: Subnet.count minus the exclusion pairs (5 today) — derived,
#   never hardcoded.
#
# Used by the Device model validation, the NAT assign tools, and the
# Add-IP button cap, so the form, the chat, and the API can never disagree.
# Branch-aware scoping is deliberately absent: no subnet carries a branch
# yet (branch_id unpopulated estate-wide); wire it here when that data
# exists.
class DeviceSubnetPolicy
  # Network addresses (with mask) identifying each exclusive side.
  EXCLUSIVE_PAIRS = [
    %w[192.168.13.0/24 192.168.30.0/24],
    %w[172.15.242.0/24 172.16.242.0/24]
  ].freeze

  def self.max_rows
    # Only pairs whose both sides exist constrain the count: a rule about
    # subnets that aren't inventoried is vacuous, not a deduction.
    applicable = EXCLUSIVE_PAIRS.count { |pair| resolve_pair(pair).all? }
    Subnet.count - applicable
  end

  # Returns an array of human-readable violations for the given IPs
  # (IpAddress records or ids). Empty means the set is legal.
  def self.violations(ip_addresses)
    ips = Array(ip_addresses).map { |ip| ip.is_a?(IpAddress) ? ip : IpAddress.find_by(id: ip) }.compact
    return [] if ips.size < 2

    messages = []
    by_subnet = ips.group_by(&:subnet_id)

    by_subnet.each_value do |group|
      if group.size > 1
        messages << "holds #{group.size} IPs from #{group.first.subnet&.name || "the same subnet"} — one series per device"
      end
    end

    pair_members = EXCLUSIVE_PAIRS.map { |pair| resolve_pair(pair) }
    held = ips.map(&:subnet_id).uniq
    pair_members.each do |a_id, b_id|
      next if a_id.nil? || b_id.nil?
      if held.include?(a_id) && held.include?(b_id)
        a_name = Subnet.find_by(id: a_id)&.name || a_id
        b_name = Subnet.find_by(id: b_id)&.name || b_id
        messages << "cannot hold both #{a_name} and #{b_name} — either side, not both"
      end
    end

    messages.uniq
  end

  def self.resolve_pair(pair)
    pair.map { |cidr| Subnet.find_by(network_address: cidr)&.id }
  end
end
