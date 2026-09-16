json.id @device.id
json.name @device.name
json.device_type @device.device_type
json.status @device.status
json.critical @device.critical
json.mac_address @device.mac_address
json.department_id @device.department_id
json.employee_id @device.employee_id
json.ip_addresses @device.ip_addresses.map { |ip| { id: ip.id, address: ip.address.to_s, status: ip.status, reachability_status: ip.reachability_status } }
