# require 'ipaddr'

# puts "🌱 Starting Database Seeding..."

# # 1. CLEANUP
# puts "   🧹 Cleaning old records..."
# # Order is critical to respect Foreign Keys
# NetworkEvent.destroy_all
# IpAddress.destroy_all # This deletes IPs attached to subnets
# Device.destroy_all
# Employee.destroy_all
# Department.destroy_all
# Subnet.destroy_all
# Branch.destroy_all
# Session.destroy_all
# User.destroy_all

# # 2. CREATE ADMIN USER
# puts "   👤 Creating Admin User..."
# User.create!(
#   email: "tolase@ipam.com",
#   username: "tolase",
#   password: "Correct-Horse-Battery-Staple-123!",
#   verified: true,
#   admin: true
# )

# # 3. DEFINE STRUCTURES
# branch_names = [
#   "Yale 1", "Yale 2", "Yale 3", "Yale 4", "Yale 5",
#   "Yale 8", "Yale 9", "Yale 12", "Yale 14",
#   "Vital", "Havard", "Sumal", "Trailer park"
# ]

# standard_depts = [
#   "Pallet Generation (Generating)", "Pallet Generation (Receiving)", "Store",
#   "Safety Engineer Office", "Personnel Office", "Personnel Manager Office",
#   "Waybill Office", "Weight Bridge", "Factory Manager"
# ]

# sumal_depts = [ "Marketing", "Account", "DHRM", "Secretary", "Personnel Office" ]
# trailer_depts = [ "Engineer Office", "Personnel Office" ]
# yale_1_extras = [ "IT Office", "HRM", "Quality Lab" ]

# # 4. CREATE BRANCHES & DEPARTMENTS
# puts "   🏢 Creating Branches and Departments..."

# branch_names.each do |b_name|
#   branch = Branch.create!(
#     name: b_name,
#     location: "Ibadan, Oyo State",
#     contact_phone: Faker::PhoneNumber.cell_phone
#   )

#   depts_to_create = if b_name == "Sumal"
#                       sumal_depts
#   elsif b_name == "Trailer park"
#                       trailer_depts
#   else
#                       list = standard_depts.dup
#                       list += yale_1_extras if b_name == "Yale 1"
#                       list
#   end

#   depts_to_create.each do |d_name|
#     Department.create!(name: d_name, branch: branch)
#   end
# end

# # 5. CREATE SUBNETS
# puts "   🌐 Creating Subnets..."
# puts "      (Model callback will automatically generate 254 empty IPs per subnet)"

# # Because of your Subnet model logic, these two lines create 508 IpAddress records automatically!
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

# # Helper to assign an existing empty IP to a device
# def assign_next_free_ip(device, subnets)
#   subnets.each do |subnet|
#     # We look for an IP that the Subnet Model already created
#     ip = subnet.ip_addresses.find_by(status: :available, device: nil)

#     if ip
#       # Simulate realistic monitoring data
#       # 80% chance it's online, 20% offline
#       is_online = rand < 0.8

#       ip.update!(
#         device: device,
#         status: :active,
#         reachability_status: is_online ? :up : :down,
#         last_seen_at: is_online ? Time.current : rand(1..30).days.ago
#       )
#       return
#     end
#   end
#   puts "   ⚠️  Warning: No IPs left for #{device.name}"
# end

# def generate_device_name(branch_name, dept_name, index)
#   if branch_name == "Yale 1" && [ "IT Office", "HRM", "Quality Lab" ].include?(dept_name)
#     prefix = dept_name.gsub(" ", "-")
#     return "#{prefix}-#{index}"
#   end

#   b_abbr = case branch_name
#   when /Yale (\d+)/ then "Y#{$1}"
#   when "Sumal" then "SUM"
#   when "Trailer park" then "TRP"
#   when "Vital" then "VIT"
#   when "Havard" then "HAV"
#   else branch_name[0..2].upcase
#   end

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
#     index = i + 1
#     name = generate_device_name(dept.branch.name, dept.name, index)

#     is_pallet_dept = dept.name.include?("Pallet")
#     owner = nil

#     unless is_pallet_dept
#       owner = Employee.create!(
#         first_name: Faker::Name.first_name,
#         last_name: Faker::Name.last_name,
#         department: dept,
#         status: :active
#       )
#     end

#     is_critical = dept.name.include?("Manager") || dept.name.include?("IT")

#     # FIX: Added "-#{type}" to the serial number to prevent collisions
#     # when the counter 'i' resets for different device types in the same department.
#     device = Device.create!(
#       name: "#{name}-#{type.to_s[0].upcase}",
##       serial_number: Faker::Device.serial + "-#{dept.id}-#{i}-#{type}",
##       asset_tag: "TAG-#{dept.id}-#{i}-#{type.to_s[0]}",
#       device_type: type,
#       status: :active,
#       department: dept,
#       employee: owner,
#       mac_address: Faker::Internet.mac_address,
#       critical: is_critical
#     )

#     assign_next_free_ip(device, subnets)
#   end
# end

# # 7. GENERATE DEVICES
# puts "   💻 Deploying Devices..."

# Department.all.includes(:branch).each do |dept|
#   case dept.name
#   when "IT Office"
#     create_devices_for_dept(dept, :desktop, 4, [ subnet_data ])
#     create_devices_for_dept(dept, :all_in_one, 2, [ subnet_data ])
#     create_devices_for_dept(dept, :laptop, 3, [ subnet_data ])

#   when "Personnel Office"
#     create_devices_for_dept(dept, :desktop, 4, [ subnet_data ])
#     create_devices_for_dept(dept, :all_in_one, 2, [ subnet_data ])

#   when "Account"
#     create_devices_for_dept(dept, :desktop, 8, [ subnet_data ])
#     create_devices_for_dept(dept, :all_in_one, 2, [ subnet_data ])

#   when "Marketing"
#     create_devices_for_dept(dept, :desktop, 5, [ subnet_data ])
#     create_devices_for_dept(dept, :laptop, 2, [ subnet_data ])

#   when "Pallet Generation (Generating)", "Pallet Generation (Receiving)"
#     create_devices_for_dept(dept, :desktop, 1, [ subnet_data ])

#   else
#     # Standard office
#     create_devices_for_dept(dept, :desktop, 2, [ subnet_data ])
#   end
# end

# # 8. SEED NETWORK EVENTS (For Dashboard)
# puts "   📊 Generating Dummy Logs..."
# if (device = Device.first)
#   NetworkEvent.create!(
#     kind: :drift,
#     ip_address: "192.168.13.105",
#     device: device,
#     message: "Device '#{device.name}' moved from previous location to 192.168.13.105"
#   )
#   NetworkEvent.create!(
#     kind: :security,
#     ip_address: "192.168.13.200",
#     message: "Rogue device detected at 192.168.13.200 (MAC: AA:BB:CC:11:22:33)"
#   )
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
# puts "Available IPs:  #{IpAddress.available.count}"
# puts "Reserved IPs:   #{IpAddress.reserved.count}"
# puts "------------------------------------------------"
