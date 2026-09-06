# db/seeds/demo.rb — Guarded demo dataset for previewing the Mainline UI.
#
# Run with:  SEED_DEMO=1 bin/rails db:seed
# Re-runs are safe: the file skips when demo data already exists.
# It never touches existing users (including your admin).
#
# Demo rows are identifiable by branch names ("Yaba HQ", "Ikeja Depot")
# and demo ranges (10.20.0.0/28, 10.20.1.0/27, 192.168.50.0/29).
# To remove everything this file creates:
#   bin/rails runner 'Branch.where(name: ["Yaba HQ", "Ikeja Depot"]).destroy_all; Board.where(name: "HQ Night Shift").destroy_all; Chat.where.not(user_id: nil).where("created_at > ?", 30.days.ago).destroy_all'
# (Review the Chat line before running — it targets recent chats.)

if Subnet.exists?(network_address: "10.20.0.0/28")
  puts "Demo seed already present, skipping."
else
  ActiveRecord::Base.transaction do
    puts "Seeding Mainline demo data..."

    # --- Organization ---
    hq = Branch.create!(name: "Yaba HQ", location: "Lagos", contact_phone: "+234 801 000 0001")
    depot = Branch.create!(name: "Ikeja Depot", location: "Lagos", contact_phone: "+234 801 000 0002")

    it_office = Department.create!(name: "IT Office", branch: hq)
    personnel = Department.create!(name: "Personnel Office", branch: hq)
    engineering = Department.create!(name: "Engineer Office", branch: depot)

    staff = [
      [ "Adaeze", "Okafor", it_office, :active ],
      [ "Tunde", "Bakare", it_office, :active ],
      [ "Chiamaka", "Eze", personnel, :active ],
      [ "Oluwaseun", "Adeyemi", personnel, :on_leave ],
      [ "Ibrahim", "Musa", engineering, :active ],
      [ "Ngozi", "Nwosu", engineering, :active ],
      [ "Emeka", "Obi", it_office, :active ],
      [ "Fatima", "Bello", engineering, :active ]
    ].map do |first, last, dept, status|
      Employee.create!(first_name: first, last_name: last, department: dept, status: status)
    end
    adaeze, tunde, chiamaka, _seun, ibrahim, ngozi, emeka, fatima = staff

    # --- Subnets (after_create auto-populates host IPs) ---
    servers = Subnet.create!(name: "Servers", network_address: "10.20.0.0/28", gateway: "10.20.0.1", vlan_id: 10)
    staff_net = Subnet.create!(name: "Staff", network_address: "10.20.1.0/27", gateway: "10.20.1.1", vlan_id: 20)
    printers = Subnet.create!(name: "Printers", network_address: "192.168.50.0/29", gateway: "192.168.50.1", vlan_id: 30)

    # --- Devices ---
    mac = ->(n) { format("02:00:00:00:00:%02X", n) }
    srv1 = Device.create!(name: "srv-dc-01", device_type: :server, status: :active, critical: true,
                          department: it_office, employee: adaeze, mac_address: mac.(1))
    srv2 = Device.create!(name: "srv-dc-02", device_type: :server, status: :active, critical: true,
                          department: it_office, employee: tunde, mac_address: mac.(2))
    rtr = Device.create!(name: "rtr-edge-01", device_type: :router, status: :active,
                         department: it_office, employee: adaeze, mac_address: mac.(3))
    laptops = [ [ "lt-ada-01", adaeze ], [ "lt-tun-01", tunde ], [ "lt-chi-01", chiamaka ],
                [ "lt-ibr-01", ibrahim ], [ "lt-ngo-01", ngozi ], [ "lt-eme-01", emeka ] ].map.with_index do |(name, owner), i|
      Device.create!(name: name, device_type: :laptop, status: :active,
                     department: owner.department, employee: owner, mac_address: mac.(10 + i))
    end
    prt_hq = Device.create!(name: "prt-hq-01", device_type: :printer, status: :active,
                            department: personnel, employee: chiamaka, mac_address: mac.(20))
    prt_depot = Device.create!(name: "prt-depot-01", device_type: :printer, status: :in_repair,
                               department: engineering, employee: ibrahim, mac_address: mac.(21))
    spare = Device.create!(name: "lt-spare-01", device_type: :laptop, status: :in_storage,
                           department: it_office, mac_address: mac.(22))
    bio = Device.create!(name: "bio-gate-01", device_type: :biometrics_machine, status: :active,
                         department: engineering, employee: fatima, location: "Main Gate",
                         mac_address: mac.(23))

    # --- IP assignments ---
    assign = lambda do |address, device:, reachability: :up, last_seen: Time.current|
      IpAddress.find_by!(address: address)
               .update!(device: device, status: :active,
                        reachability_status: reachability, last_seen_at: last_seen)
    end

    assign.call("10.20.0.2", device: srv1)
    assign.call("10.20.0.3", device: srv2, reachability: :down, last_seen: 2.hours.ago)
    assign.call("10.20.0.4", device: rtr)

    %w[10.20.1.2 10.20.1.3 10.20.1.4 10.20.1.5 10.20.1.6 10.20.1.7].zip(laptops).each do |addr, dev|
      assign.call(addr, device: dev)
    end
    assign.call("10.20.1.8", device: laptops.last, reachability: :down, last_seen: 3.days.ago)

    assign.call("192.168.50.2", device: prt_hq)
    assign.call("192.168.50.3", device: bio)
    # Ghost asset: assigned but unseen for 45 days.
    assign.call("192.168.50.4", device: prt_depot, reachability: :down, last_seen: 45.days.ago)

    # Rogue devices: reachable but unassigned (left status available on purpose).
    IpAddress.find_by!(address: "10.20.1.20").update!(reachability_status: :up, last_seen_at: 5.minutes.ago)
    IpAddress.find_by!(address: "10.20.0.10").update!(reachability_status: :up, last_seen_at: 12.minutes.ago)

    # --- Network events ---
    NetworkEvent.create!([
      { kind: :info, ip_address: "10.20.0.2", message: "Scheduled scan completed (14/14 hosts checked).", created_at: 20.minutes.ago },
      { kind: :security, ip_address: "10.20.1.20", message: "Unknown device responded to ping; no matching inventory record.", created_at: 15.minutes.ago },
      { kind: :drift, ip_address: "10.20.0.3", device: srv2, message: "srv-dc-02 stopped responding (was up 6d 4h).", created_at: 2.hours.ago },
      { kind: :outage, ip_address: "192.168.50.4", device: prt_depot, message: "prt-depot-01 unreachable for 45 days; candidate for reclaim.", created_at: 5.hours.ago },
      { kind: :info, ip_address: "10.20.1.8", device: laptops.last, message: "lt-eme-01 last seen 3 days ago.", created_at: 1.day.ago },
      { kind: :info, ip_address: "10.20.1.1", message: "Gateway latency normal (0.4ms avg).", created_at: 2.days.ago },
      { kind: :drift, ip_address: "192.168.50.2", device: prt_hq, message: "prt-hq-01 MAC changed after maintenance.", created_at: 3.days.ago },
      { kind: :security, ip_address: "10.20.0.10", message: "Unknown device on Servers VLAN; investigate.", created_at: 4.days.ago }
    ])

    # --- Ops board ---
    board = Board.create!(name: "HQ Night Shift", description: "Overnight network tasks for the Yaba HQ on-call rotation.")
    todo = List.create!(name: "To Do", board: board, position: 1)
    doing = List.create!(name: "Doing", board: board, position: 2)
    done = List.create!(name: "Done", board: board, position: 3)

    admin = User.find_by(email: "tolase@mainline.com")
    c1 = Card.create!(title: "Replace faulty switch in Server Room", list: todo, position: 1,
                      priority: :high, description: "srv-dc-02 dropped off the network; check switch port first.",
                      referenceable: srv2)
    c2 = Card.create!(title: "Investigate rogue IP 10.20.1.20", list: todo, position: 2,
                      priority: :high, description: "Unknown device on Staff VLAN, first seen 15 minutes ago.")
    rogue_ip = IpAddress.find_by!(address: "10.20.1.20")
    c2.update!(referenceable: rogue_ip)
    Card.create!(title: "Reclaim ghost printer IP 192.168.50.4", list: todo, position: 3,
                 priority: :medium, description: "prt-depot-01 unseen for 45 days; confirm with engineering, then reclaim.")
    Card.create!(title: "Patch staff laptops", list: doing, position: 1,
                 priority: :low, description: "Rolling OS updates for the 6 assigned laptops.")
    Card.create!(title: "Rack cleanup", list: done, position: 1,
                 priority: :low, description: "Labelled all ports in rack 2.")
    [ c1, c2 ].each { |c| c.users << admin } if admin

    # --- Sample NAT conversation ---
    if admin
      default_model = Model.find_by(model_id: "gemini-3.1-flash-lite", provider: "gemini")
      chat = Chat.create!(user: admin, model: default_model)
      chat.messages.create!(role: "user", content: "How many rogue devices are on the network right now?")
      chat.messages.create!(role: "assistant", content: "There are 2 rogue devices: 10.20.1.20 (Staff) and 10.20.0.10 (Servers). Both responded to ping but have no inventory record. Want me to draft investigation tasks for them?")
    end

    puts "Demo seed complete: " \
         "#{Branch.count} branches, #{Department.count} departments, #{Employee.count} employees, " \
         "#{Subnet.count} subnets, #{IpAddress.count} IPs, #{Device.count} devices, " \
         "#{NetworkEvent.count} events, #{Board.count} board, #{Card.count} cards, #{Chat.count} chats."
  end
end
