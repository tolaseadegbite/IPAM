json.id @subnet.id
json.name @subnet.name
json.network_address @subnet.network_address.to_s
json.gateway @subnet.gateway.to_s
json.vlan_id @subnet.vlan_id
json.total_ips @subnet.ip_addresses.count
json.used_ips @subnet.ip_addresses.where(status: [ :active, :reserved ]).count
