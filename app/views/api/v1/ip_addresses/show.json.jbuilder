json.id @ip_address.id
json.address @ip_address.address.to_s
json.status @ip_address.status
json.reachability_status @ip_address.reachability_status
json.last_seen_at @ip_address.last_seen_at
json.subnet_id @ip_address.subnet_id
json.device_id @ip_address.device_id
json.notes @ip_address.notes
