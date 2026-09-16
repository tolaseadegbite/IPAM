json.data do
  json.array! @devices do |device|
    json.id device.id
    json.name device.name
    json.device_type device.device_type
    json.status device.status
    json.critical device.critical
    json.department_id device.department_id
    json.employee_id device.employee_id
  end
end
json.meta @meta
