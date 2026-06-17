class LookupBranch < RubyLLM::Tool
  desc "Search for branches by name or location, including departments, devices, and their IP addresses"

  param :query, desc: "Branch name or location to search for"

  def execute(query:)
    Branch.where("name ILIKE :q OR location ILIKE :q", q: "%#{query}%")
          .limit(10)
          .map do |b|
      departments = b.departments.map(&:name)
      devices = b.devices.limit(20).map do |d|
        {
          name: d.name,
          type: d.device_type,
          status: d.status,
          ip_addresses: d.ip_addresses.map { |ip| { address: ip.address.to_s, reachability: ip.reachability_status } }
        }
      end

      {
        id: b.id,
        name: b.name,
        location: b.location,
        departments: departments,
        devices: devices
      }
    end
  end
end
