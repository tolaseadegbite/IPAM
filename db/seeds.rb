# # db/seeds.rb

# puts "🌱 Starting Database Seeding..."

# # 1. CLEANUP
# puts "   Cleaning old records..."
# IpAddress.destroy_all
# Device.destroy_all
# Employee.destroy_all
# Department.destroy_all
# Subnet.destroy_all
# Branch.destroy_all
# Session.destroy_all
# User.destroy_all

# # 2. CREATE ADMIN USER
# puts "   Creating Admin User..."
# User.create!(
#   email: "tolase@ipam.com",
#   username: "tolase",
#   password: "Correct-Horse-Battery-Staple-123!",
#   verified: true
# )

# # 3. DEFINE STRUCTURES
# # Branches
# branch_names = [
#   "Yale 1", "Yale 2", "Yale 3", "Yale 4", "Yale 5",
#   "Yale 8", "Yale 9", "Yale 12", "Yale 14",
#   "Vital", "Havard", "Sumal", "Trailer park"
# ]

# # Department Definitions
# standard_depts = [
#   "Pallet Generation (Generating)", "Pallet Generation (Receiving)", "Store",
#   "Safety Engineer Office", "Personnel Office", "Personnel Manager Office",
#   "Waybill Office", "Weight Bridge", "Factory Manager"
# ]

# sumal_depts = [ "Marketing", "Account", "DHRM", "Secretary", "Personnel Office" ]
# trailer_depts = [ "Engineer Office", "Personnel Office" ]
# yale_1_extras = [ "IT Office", "HRM", "Quality Lab" ]

# # 4. CREATE BRANCHES & DEPARTMENTS
# puts "   Creating Branches and Departments..."

# branch_names.each do |b_name|
#   branch = Branch.create!(
#     name: b_name,
#     location: "Ibadan, Oyo State",
#     contact_phone: Faker::PhoneNumber.cell_phone
#   )

#   # Determine Department List
#   depts_to_create = if b_name == "Sumal"
#                       sumal_depts
#   elsif b_name == "Trailer park"
#                       trailer_depts
#   else
#                       # Standard list + Extras if Yale 1
#                       list = standard_depts.dup
#                       list += yale_1_extras if b_name == "Yale 1"
#                       list
#   end

#   # Create Departments
#   depts_to_create.each do |d_name|
#     Department.create!(name: d_name, branch: branch)
#   end
# end

# # 5. CREATE SUBNETS (Auto-IP Generation)
# puts "   Creating Subnets..."
# # Note: With ~13 branches and ~200+ devices, 2 subnets might fill up.
# subnet_data = Subnet.create!(
#   name: "Corporate Data (.13)",
#   network_address: "192.168.13.0/24",
#   gateway: "192.168.13.1",
#   vlan_id: 10
# )

# subnet_mgmt = Subnet.create!(
#   name: "Management (.30)",
#   network_address: "192.168.30.0/24",
#   gateway: "192.168.30.1",
#   vlan_id: 20
# )

# # 6. HELPERS FOR DEVICES

# # Helper to assign IP
# def assign_next_free_ip(device, subnets)
#   # Try subnets in order until one has space
#   subnets.each do |subnet|
#     ip = subnet.ip_addresses.find_by(status: :available, device: nil)
#     if ip
#       ip.update!(device: device, status: :active)
#       return
#     end
#   end
#   puts "   ⚠️  Warning: No IPs left for #{device.name}"
# end

# # Helper to generate Name: "Y2-PM-Office-1" or "IT-Office-1"
# def generate_device_name(branch_name, dept_name, index)
#   # Special exception for unique Yale 1 offices
#   if branch_name == "Yale 1" && [ "IT Office", "HRM", "Quality Lab" ].include?(dept_name)
#     prefix = dept_name.gsub(" ", "-") # "IT Office" -> "IT-Office"
#     return "#{prefix}-#{index}"
#   end

#   # Branch Abbreviation
#   b_abbr = case branch_name
#   when /Yale (\d+)/ then "Y#{$1}"
#   when "Sumal" then "SUM"
#   when "Trailer park" then "TRP"
#   when "Vital" then "VIT"
#   when "Havard" then "HAV"
#   else branch_name[0..2].upcase
#   end

#   # Department Abbreviation (Sluggify)
#   d_abbr = case dept_name
#   when "Pallet Generation (Generating)" then "Pallet-Gen"
#   when "Pallet Generation (Receiving)" then "Pallet-Rec"
#   when "Safety Engineer Office" then "Safety"
#   when "Personnel Manager Office" then "PM-Mgr"
#   when "Factory Manager" then "Fact-Mgr"
#   when "Weight Bridge" then "Weight-B"
#   else dept_name.gsub(" ", "-")
#   end

#   "#{b_abbr}-#{d_abbr}-#{index}"
# end

# # Helper to batch create devices AND employees
# def create_devices_for_dept(dept, type, count, subnets)
#   count.times do |i|
#     # 1-based index for naming
#     index = i + 1

#     name = generate_device_name(dept.branch.name, dept.name, index)

#     # LOGIC: Check if this department should have assigned users
#     is_pallet_dept = [
#       "Pallet Generation (Generating)",
#       "Pallet Generation (Receiving)"
#     ].include?(dept.name)

#     owner = nil

#     # Create an employee UNLESS it is a Pallet Generation department
#     unless is_pallet_dept
#       owner = Employee.create!(
#         first_name: Faker::Name.first_name,
#         last_name: Faker::Name.last_name,
#         department: dept,
#         status: :active
#       )
#     end

#     device = Device.create!(
#       name: "#{name}-#{type.to_s[0].upcase}", # Append -D, -L, -A
#       serial_number: Faker::Device.serial + "-#{dept.id}-#{i}-#{type}",
#       asset_tag: "TAG-#{dept.id}-#{i}-#{type.to_s[0]}",
#       device_type: type,
#       status: :active,
#       department: dept,
#       employee: owner
#     )

#     assign_next_free_ip(device, subnets)
#   end
# end

# # 7. GENERATE DEVICES
# puts "   Deploying Devices to Offices..."

# Department.all.includes(:branch).each do |dept|
#   # Determine Device Count based on Dept Name
#   case dept.name
#   when "IT Office"
#     create_devices_for_dept(dept, :desktop, 4, [ subnet_data, subnet_mgmt ])
#     create_devices_for_dept(dept, :all_in_one, 2, [ subnet_data, subnet_mgmt ])
#     create_devices_for_dept(dept, :laptop, 3, [ subnet_data, subnet_mgmt ])

#   when "Personnel Office"
#     create_devices_for_dept(dept, :desktop, 4, [ subnet_data, subnet_mgmt ])
#     create_devices_for_dept(dept, :all_in_one, 2, [ subnet_data, subnet_mgmt ])

#   when "Account"
#     create_devices_for_dept(dept, :desktop, 8, [ subnet_data, subnet_mgmt ])
#     create_devices_for_dept(dept, :all_in_one, 2, [ subnet_data, subnet_mgmt ])

#   when "Marketing"
#     create_devices_for_dept(dept, :desktop, 5, [ subnet_data, subnet_mgmt ])
#     create_devices_for_dept(dept, :laptop, 2, [ subnet_data, subnet_mgmt ])

#   when "Pallet Generation (Generating)", "Pallet Generation (Receiving)"
#     # These will be created WITHOUT employees based on helper logic
#     create_devices_for_dept(dept, :desktop, 1, [ subnet_data, subnet_mgmt ])

#   else
#     # "Every other office should have at least 2 desktop computers"
#     create_devices_for_dept(dept, :desktop, 2, [ subnet_data, subnet_mgmt ])
#   end
# end

# puts "✅ Seeding Complete!"
# puts "------------------------------------------------"
# puts "Admin Login:    tolase@ipam.com"
# puts "Password:       Correct-Horse-Battery-Staple-123!"
# puts "------------------------------------------------"
# puts "Branches:       #{Branch.count}"
# puts "Departments:    #{Department.count}"
# puts "Devices:        #{Device.count}"
# puts "Employees:      #{Employee.count}"
# puts "Allocated IPs:  #{IpAddress.active.count}"
# puts "------------------------------------------------"
