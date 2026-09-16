json.data do
  json.array! @ip_addresses do |ip|
    json.id ip.id
    json.address ip.address.to_s
    json.status ip.status
    json.reachability_status ip.reachability_status
    json.last_seen_at ip.last_seen_at
    json.subnet_id ip.subnet_id
    json.device_id ip.device_id
  end
end
json.meta @meta
