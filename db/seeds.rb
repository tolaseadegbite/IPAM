# db/seeds.rb

puts "🌱 Starting Database Seeding..."

# 1. CLEANUP
puts "   Cleaning old records..."
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
  # Must be >12 chars per your User model validation
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
puts "   Creating Subnets..."
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

# 6. POPULATE IP ADDRESSES
puts "   Populating IP Addresses..."

def populate_subnet(subnet, range)
  # Logic: Take "192.168.13.0" -> "192.168.13"
  base_ip_string = subnet.network_address.to_s.split('.')[0...3].join('.')
  
  range.each do |i|
    # Create the IP. The model validation we just fixed will run here.
    subnet.ip_addresses.create!(
      address: "#{base_ip_string}.#{i}",
      status: :available
    )
  end
end

populate_subnet(subnet_data, 2..50)
populate_subnet(subnet_mgmt, 2..50)

# 7. CREATE EMPLOYEES
puts "   Onboarding Employees..."
employees = []

# Specific employees
employees << Employee.create!(first_name: "Sarah", last_name: "Connor", email: "sarah.connor@ipam.com", department: depts[0], status: :active)
employees << Employee.create!(first_name: "John", last_name: "Doe", email: "john.doe@ipam.com", department: depts[2], status: :active)
employees << Employee.create!(first_name: "Alex", last_name: "Admin", email: "alex.admin@ipam.com", department: depts[1], status: :active)

# Random employees via Faker
10.times do
  employees << Employee.create!(
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    email: Faker::Internet.email,
    department: depts.sample,
    status: :active
  )
end

# 8. DEPLOY DEVICES & ASSIGN IPs
puts "   Deploying Devices..."

def assign_ip(subnet, device)
  # Find first available IP
  ip = subnet.ip_addresses.find_by(status: :available, device: nil)
  if ip
    ip.update!(device: device, status: :active)
  end
end

# Device A
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

# Device B
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
    serial_number: Faker::Device.serial,
    asset_tag: "TAG-#{500+i}",
    device_type: :laptop,
    status: :active,
    department: depts.sample,
    employee: employees.sample
  )
  target_subnet = [subnet_data, subnet_mgmt].sample
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
puts "Used IPs:       #{IpAddress.where.not(device_id: nil).count}"
puts "Devices:        #{Device.count}"
puts "Employees:      #{Employee.count}"
puts "------------------------------------------------"