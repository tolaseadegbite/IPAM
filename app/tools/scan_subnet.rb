class ScanSubnet < RubyLLM::Tool
  description "Start a live network rescan of one subnet. The scan runs in the background (minutes); tell the user to ask again after it finishes instead of inventing fresh numbers."

  parameter :subnet_id, type: "integer", description: "Subnet ID to rescan (optional when query is given)", required: false
  parameter :query, description: "Subnet name or CIDR fragment to rescan (optional when subnet_id is given)", required: false

  def execute(subnet_id: nil, query: nil)
    subnet = if subnet_id.present?
      Subnet.find_by(id: subnet_id)
    elsif query.present?
      matches = Subnet.where(
        "name ILIKE :q OR network_address::text ILIKE :q", q: "%#{query}%"
      ).limit(2).to_a
      if matches.size > 1
        names = matches.map(&:name).to_sentence
        return "Multiple subnets match '#{query}': #{names}. Ask the user which one to rescan."
      end
      matches.first
    end

    unless subnet
      return "Subnet not found. Use LookupSubnet to find the subnet ID."
    end

    # Single-scan batch: same completion protocol SubnetScanJob speaks.
    batch_id = "#{Time.current.to_i}-#{SecureRandom.hex(4)}"
    Rails.cache.write("scan_batch_#{batch_id}", 1, expires_in: 1.hour)
    SubnetScanJob.perform_later(subnet.id, batch_id)

    "Rescan of '#{subnet.name}' (#{subnet.network_address}) started. It runs in the background for a few minutes — ask me again afterwards for fresh numbers."
  end
end
