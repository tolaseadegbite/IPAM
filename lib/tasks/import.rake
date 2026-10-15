# Import the estate inventory spreadsheets (db/imports/).
#
#   bin/rails import:spreadsheet        # dry-run report, changes nothing
#   bin/rails import:spreadsheet[LIVE]  # performs the import (LIVE=1)
namespace :import do
  # Duplicate departments confirmed as typos (source => target). Member
  # employees and devices move to the target, then the source is deleted.
  DEPT_MERGES = {
    "Engineer Marukia" => "Engineer Maruwa",
    "Engineer Praju" => "Engr Praju's Office"
  }.freeze

  # Duplicate employee records confirmed as typos. Deleted only when they
  # hold no devices; otherwise their devices move to the surviving record.
  DUPE_EMPLOYEES = [
    [ "Engineer Praju", "Engr Praju" ],
    [ "Engineer Nemesh", "Engr Nemesh" ]
  ].freeze

  desc "Apply pre-import cleanups (dept merges, dupe people, .13.2 gateway). LIVE=1 to write."
  task preconditions: :environment do
    live = ENV["LIVE"] == "1"
    puts(live ? "LIVE preconditions run" : "DRY-RUN (pass LIVE=1 to write)")

    DEPT_MERGES.each do |source_name, target_name|
      source = Department.find_by(name: source_name)
      target = Department.find_by(name: target_name)
      if source.nil?
        puts "  merge skipped (already gone?): #{source_name}"
        next
      end
      unless target
        puts "  merge BLOCKED: target missing: #{target_name}"
        next
      end
      members = "#{source.employees.count} people, #{source.devices.count} devices"
      puts "  merge #{source_name} -> #{target_name} (#{members})"
      next unless live
      ActiveRecord::Base.transaction do
        source.employees.update_all(department_id: target.id)
        source.devices.update_all(department_id: target.id)
        # update_all skips callbacks/counters: refresh caches and the
        # association state restrict_with_error checks before destroying.
        %w[employees devices].each do |assoc|
          Department.reset_counters(source.id, assoc)
          Department.reset_counters(target.id, assoc)
        end
        source.reload.destroy!
      end
    end

    DUPE_EMPLOYEES.each do |dupe_name, keeper_name|
      dupe = Employee.find_by(first_name: dupe_name.split.first, last_name: dupe_name.split.last)
      # Keepers may use either convention ("Engr"/"Praju" or "Engr Praju"/"").
      keeper = Employee.find_by(first_name: keeper_name.split.first, last_name: keeper_name.split.last) ||
               Employee.find_by(first_name: keeper_name)
      if dupe.nil?
        puts "  dupe gone already: #{dupe_first}"
        next
      end
      puts "  dupe #{dupe.full_name} (#{dupe.devices.count} devices) keeper=#{keeper&.full_name || "none"}"
      next unless live
      ActiveRecord::Base.transaction do
        if keeper && dupe.devices.any?
          dupe.devices.update_all(employee_id: keeper.id)
        end
        dupe.destroy! if dupe.devices.none?
      end
    end

    gateway = IpAddress.where("host(address) = ?", "192.168.13.2").first
    if gateway.nil?
      puts "  .13.2 row missing!"
    elsif gateway.reserved? && gateway.notes.to_s.include?("Biometrics")
      puts "  .13.2 already reserved as biometrics gateway"
    else
      puts "  reserve 192.168.13.2 (now #{gateway.status}, device=#{gateway.device&.name || "-"}) as biometrics gateway"
      if live
        gateway.update!(status: :reserved, device: nil,
                        notes: [ gateway.notes.presence, "Biometrics gateway (reserved at import)." ].compact.join(" | "))
      end
    end
  end

  desc "Import estate inventory spreadsheets (LIVE=1 to write, default dry-run)"
  task :spreadsheet, [ :live ] => :environment do |_, args|
    live = args[:live] == "LIVE" || ENV["LIVE"] == "1"
    puts(live ? "LIVE import run" : "DRY-RUN (pass LIVE=1 to write)")
    report = SpreadsheetImportService.call(dry_run: !live)

    devices = live ? report[:created_devices] : report[:planned_devices]
    links = live ? report[:linked] : report[:planned_links]
    puts "Devices: #{devices.size} (reused existing: #{report[:reused_devices].size}, merged rows: #{report[:merged_rows].size})"
    puts "Branches: #{((report[:created_branches] + report[:planned_branches]).uniq).inspect}"
    puts "Departments created: #{(report[:created_departments] + report[:planned_departments]).uniq.size}"
    puts "Employees: #{((report[:created_employees] + report[:planned_employees]).uniq).inspect}"
    puts "Links: #{links.size} (agreed already-linked: #{report[:agreed].size})"
    puts "Conflicts kept (DB wins): #{report[:conflicts_kept].size}"
    puts "MAC fills: #{(report[:mac_fills] + report[:planned_mac_fills]).size}"
    puts "MAC conflicts kept: #{report[:mac_conflicts].size}"
    puts "Owner fills: #{(report[:owner_fills] + report[:planned_owner_fills]).size}"
    puts "Skipped FREE rows: #{report[:skipped_free].size}"
    puts "Skipped blank listings: #{report[:skipped_blank].size}"
    puts "Skipped cameras: #{report[:skipped_cameras].size}"
    puts "Skipped missing IPs: #{report[:skipped_missing].size}"
    puts "Unmappable rows: #{report[:unmappable].size}"
    puts "Dept fallbacks to Facilities: #{report[:dept_fallback].size}"
    puts "Errors: #{report[:errors].size}"
    report[:unmappable].first(15).each { |line| puts "  UNMAPPABLE: #{line}" }
    report[:errors].first(15).each { |line| puts "  ERROR: #{line}" }
    report[:conflicts_kept].first(10).each { |line| puts "  KEPT: #{line}" }
  end
end
