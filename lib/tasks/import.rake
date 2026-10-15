# Import the estate inventory spreadsheets (db/imports/).
#
#   bin/rails import:spreadsheet        # dry-run report, changes nothing
#   bin/rails import:spreadsheet[LIVE]  # performs the import (LIVE=1)
namespace :import do
  desc "Import estate inventory spreadsheets (LIVE=1 to write, default dry-run)"
  task :spreadsheet, [ :live ] => :environment do |_, args|
    live = args[:live] == "LIVE" || ENV["LIVE"] == "1"
    puts(live ? "LIVE import run" : "DRY-RUN (pass LIVE=1 to write)")
    report = SpreadsheetImportService.call(dry_run: !live)

    devices = live ? report[:created_devices] : report[:planned_devices]
    links = live ? report[:linked] : report[:planned_links]
    puts "Devices: #{devices.size} (#{devices.first(10).join(", ")})"
    puts "Departments created: #{(report[:created_departments] + report[:planned_departments]).uniq.size}"
    puts "Links: #{links.size} (agreed already-linked: #{report[:agreed].size})"
    puts "Conflicts kept (DB wins): #{report[:conflicts_kept].size}"
    puts "MAC fills: #{(report[:mac_fills] + report[:planned_mac_fills]).size}"
    puts "MAC conflicts kept: #{report[:mac_conflicts].size}"
    puts "Skipped FREE rows: #{report[:skipped_free].size}"
    puts "Skipped blank listings: #{report[:skipped_blank].size}"
    puts "Skipped missing IPs: #{report[:skipped_missing].size}"
    puts "Unmappable rows: #{report[:unmappable].size}"
    puts "Dept fallbacks to Facilities: #{report[:dept_fallback].size}"
    puts "Merged multi-row devices: #{report[:merged_rows].size}"
    puts "Errors: #{report[:errors].size}"
    report[:unmappable].first(15).each { |line| puts "  UNMAPPABLE: #{line}" }
    report[:errors].first(15).each { |line| puts "  ERROR: #{line}" }
    report[:conflicts_kept].first(10).each { |line| puts "  KEPT: #{line}" }
  end
end
