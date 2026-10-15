require "test_helper"
require "zip"

class SpreadsheetRowParserTest < ActiveSupport::TestCase
  setup do
    @inventory_path = write_fixture_xlsx("parser_inventory.xlsx", {
      ".13 SERIES" => [
        [ ".13 SERIES" ],
        [],
        [ "", "S/N", "S/N", "FACTORY", "DEVICE", "INTERNET IP", "OFFICE/DEPT" ],
        [ "", "1", "192.168.13.10", "YALE 1", "DESKTOP", "172.16.242.99", "ACCT OFFICE MR KENY" ],
        [ "", "2", "192.168.13.11", "FREE", "FREE", "FREE", "FREE" ],
        [ "", "3", "192.168.13.12", "YALE 1", "LAPTOP", "172.16.24.89", "ACCT OFFICE MR KENY" ]
      ],
      ".15 SERIES" => [
        [ ".15 SERIES" ],
        [],
        [ "", "S/N", "IP ADDRESS", "FACTORY", "DEVICE", "OFFICE/DEPT" ],
        [ "", "1", "192.168.30.5", "YALE 1", "MR TUNDE ACCOUNT", "LAPTOP/ACCT" ]
      ],
      "MIKROTIK " => [
        [ "MIKROTIK" ],
        [ 13.156 ],
        [ 14.155 ]
      ]
    })
    @internet_path = write_fixture_xlsx("parser_internet.xlsx", {
      "INT. IP ADDRESS" => [
        [ "User Name", "Device Model/ Name", "Location", "IP Address", "Subnet Mask", "Status", "Description", "Radio IP Address", "MAC Address" ],
        [ "camera 11", nil, nil, "172.16.242.11", "255.255.255.0", "Used", "Router", "R-01-001", "AA-BB-CC-DD-EE-FF" ],
        [ "tester", nil, "Yale 5", "172.16.242.20", "255.255.255.0", "Used", "DESKTOP", nil, nil ]
      ]
    })
  end

  teardown do
    FileUtils.rm_f([ @inventory_path, @internet_path ])
  end

  test "parses data and internet IPs from one series row" do
    entries = SpreadsheetRowParser.parse(inventory_path: @inventory_path, internet_path: @internet_path)
    row_entries = entries.select { |entry| entry.row_id == "inventory/.13 SERIES#4" }
    assert_equal %w[172.16.242.99 192.168.13.10], row_entries.map(&:ip).sort
    assert_equal "YALE 1", row_entries.first.factory
  end

  test "skips FREE rows and fixes the 172.16.24.89 typo" do
    entries = SpreadsheetRowParser.parse(inventory_path: @inventory_path, internet_path: @internet_path)
    free = entries.select { |entry| entry.ip == "192.168.13.11" }
    assert_equal [ true ], free.map(&:free).uniq
    typo = entries.find { |entry| entry.row_id == "inventory/.13 SERIES#6" && entry.ip == "172.16.242.89" }
    assert_not_nil typo
  end

  test "emits MIKROTIK sheet rows as normal assigned rows" do
    entries = SpreadsheetRowParser.parse(inventory_path: @inventory_path, internet_path: @internet_path)
    mikrotik = entries.select { |entry| entry.sheet == "MIKROTIK" }
    assert_equal %w[192.168.13.156 192.168.14.155], mikrotik.map(&:ip).sort
  end

  test "normalizes blackman MACs and skips the mask column" do
    entries = SpreadsheetRowParser.parse(inventory_path: @inventory_path, internet_path: @internet_path)
    assert_empty entries.select { |entry| entry.ip == "255.255.255.0" }
    camera = entries.find { |entry| entry.ip == "172.16.242.11" }
    assert_equal "aa:bb:cc:dd:ee:ff", camera.mac
    assert_equal "camera 11", camera.user_name
  end

  private

  def write_fixture_xlsx(filename, sheets)
    path = Rails.root.join("tmp", "pid#{Process.pid}_#{filename}").to_s
    FileUtils.rm_f(path)
    Zip::File.open(path, create: true) do |zip|
      zip.get_output_stream("[Content_Types].xml") { |f| f.write(content_types(sheets.size)) }
      zip.get_output_stream("_rels/.rels") { |f| f.write(root_rels) }
      zip.get_output_stream("xl/workbook.xml") { |f| f.write(workbook(sheets.keys)) }
      zip.get_output_stream("xl/styles.xml") { |f| f.write(styles) }
      zip.get_output_stream("xl/_rels/workbook.xml.rels") { |f| f.write(workbook_rels(sheets.size)) }
      sheets.each_value.with_index(1) do |rows, index|
        zip.get_output_stream("xl/worksheets/sheet#{index}.xml") { |f| f.write(worksheet(rows)) }
      end
    end
    path
  end

  def styles
    %(<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts><fills count="1"><fill><patternFill patternType="none"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs></styleSheet>)
  end

  def content_types(count)
    overrides = (1..count).map do |index|
      %(<Override PartName="/xl/worksheets/sheet#{index}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>)
    end.join
    %(<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>#{overrides}<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/></Types>)
  end

  def root_rels
    %(<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>)
  end

  def workbook(names)
    sheets = names.each_with_index.map do |name, index|
      %(<sheet name="#{name}" sheetId="#{index + 1}" r:id="rId#{index + 1}"/>)
    end.join
    %(<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>#{sheets}</sheets></workbook>)
  end

  def workbook_rels(count)
    rels = (1..count).map do |index|
      %(<Relationship Id="rId#{index}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet#{index}.xml"/>)
    end.join
    %(<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">#{rels}</Relationships>)
  end

  def worksheet(rows)
    data = rows.each_with_index.map do |cells, row_index|
      refs = cells.each_with_index.map do |value, col_index|
        next if value.nil? || value.to_s.strip.empty?
        ref = "#{(65 + col_index).chr}#{row_index + 1}"
        if value.is_a?(Numeric)
          %(<c r="#{ref}"><v>#{value}</v></c>)
        else
          %(<c r="#{ref}" t="inlineStr"><is><t>#{value}</t></is></c>)
        end
      end.compact.join
      %(<row r="#{row_index + 1}">#{refs}</row>)
    end.join
    %(<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>#{data}</sheetData></worksheet>)
  end
end
