json.data do
  json.array! @subnets do |subnet|
    json.id subnet.id
    json.name subnet.name
    json.network_address subnet.network_address.to_s
    json.gateway subnet.gateway.to_s
    json.vlan_id subnet.vlan_id
  end
end
json.meta @meta
