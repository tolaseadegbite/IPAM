# db/seeds.rb

puts "🌱 Starting Database Seeding..."

# 1. CLEANUP
puts "   Cleaning old records..."
# Order matches Foreign Key constraints (Child -> Parent)
IpAddress.destroy_all
Device.destroy_all
Employee.destroy_all
Department.destroy_all
Subnet.destroy_all
Branch.destroy_all
Session.destroy_all
User.destroy_all

# 2. CREATE ADMIN USER
puts "   Creating Admin User..."
User.create!(
  email: "tolase@ipam.com",
  username: "tolase",
  password: "Correct-Horse-Battery-Staple-123!",
  verified: true
)

# 3. CREATE BRANCHES
puts "   Creating Branches..."
branches = []
branches << Branch.create!(name: "Yale 1", location: "123 Yale Ave, Building A", contact_phone: "555-0101")
branches << Branch.create!(name: "Yale 5", location: "456 Yale Blvd, Building E", contact_phone: "555-0105")

# 4. CREATE DEPARTMENTS
puts "   Creating Departments..."
depts = []
depts << Department.create!(name: "Safety Engineer Office", branch: branches[0])
depts << Department.create!(name: "IT Operations", branch: branches[0])
depts << Department.create!(name: "PM Office", branch: branches[1])
depts << Department.create!(name: "Human Resources", branch: branches[1])

# 5. CREATE SUBNETS
# NOTE: The 'after_create' callback in Subnet model automatically generates IPs
# AND marks the Gateway (.1) as Reserved.
puts "   Creating Subnets (and auto-generating IPs)..."

subnet_data = Subnet.create!(
  name: "Corporate Data (.13)",
  network_address: "192.168.13.0/24",
  gateway: "192.168.13.1",
  vlan_id: 10
)

subnet_mgmt = Subnet.create!(
  name: "Management (.30)",
  network_address: "192.168.30.0/24",
  gateway: "192.168.30.1",
  vlan_id: 20
)

# 6. CREATE EMPLOYEES
puts "   Onboarding Employees..."
employees = []

# Specific employees (Removed Email)
employees << Employee.create!(first_name: "Sarah", last_name: "Connor", department: depts[0], status: :active)
employees << Employee.create!(first_name: "John", last_name: "Doe", department: depts[2], status: :active)
employees << Employee.create!(first_name: "Alex", last_name: "Admin", department: depts[1], status: :active)

# Random employees via Faker (Removed Email)
10.times do
  employees << Employee.create!(
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    department: depts.sample,
    status: :active
  )
end

# 7. DEPLOY DEVICES & ASSIGN IPs
puts "   Deploying Devices..."

def assign_ip(subnet, device)
  # Find first available IP
  # Note: This will correctly skip the .1 Gateway because the model marked it 'Reserved'
  ip = subnet.ip_addresses.find_by(status: :available, device: nil)

  if ip
    # The IpAddress model 'before_validation' callback will automatically
    # switch status to 'active' when a device is attached.
    ip.update!(device: device, status: :active)
  else
    puts "   ⚠️  Warning: No IPs left in #{subnet.name} for #{device.name}"
  end
end

# Device A: Sarah's Laptop
laptop = Device.create!(
  name: "LPT-SAFETY-01",
  serial_number: "SN-LPT-1001",
  asset_tag: "TAG-001",
  device_type: :laptop,
  status: :active,
  department: depts[0],
  employee: employees[0],
  notes: "Standard Safety Engineer issue"
)
assign_ip(subnet_data, laptop)

# Device B: John's Desktop
desktop = Device.create!(
  name: "DSK-PM-05",
  serial_number: "SN-DSK-2020",
  asset_tag: "TAG-002",
  device_type: :desktop,
  status: :active,
  department: depts[2],
  employee: employees[1],
  notes: "High performance workstation"
)
assign_ip(subnet_mgmt, desktop)

# Random Devices
5.times do |i|
  d = Device.create!(
    name: "LPT-POOL-#{100+i}",
    # FIX: Append "-#{i}" to ensure uniqueness if Faker repeats itself
    serial_number: "#{Faker::Device.serial}-#{i}",
    asset_tag: "TAG-#{500+i}",
    device_type: :laptop,
    status: :active,
    department: depts.sample,
    employee: employees.sample
  )
  target_subnet = [ subnet_data, subnet_mgmt ].sample
  assign_ip(target_subnet, d)
end

puts "✅ Seeding Complete!"
puts "------------------------------------------------"
puts "Admin Login:    tolase@ipam.com"
puts "Password:       Correct-Horse-Battery-Staple-123!"
puts "------------------------------------------------"
puts "Branches:       #{Branch.count}"
puts "Departments:    #{Department.count}"
puts "Subnets:        #{Subnet.count}"
puts "Total IPs:      #{IpAddress.count}"
puts "Reserved IPs:   #{IpAddress.reserved.count} (Gateways)"
puts "Active IPs:     #{IpAddress.active.count} (Devices)"
puts "Devices:        #{Device.count}"
puts "Employees:      #{Employee.count}"
puts "------------------------------------------------"
