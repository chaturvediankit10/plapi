class RateSheetExtractor::ObBluePointMortgageWholesale6187Controller < RateSheetExtractor::ApplicationController
  include SheetOperation

  def index
    sub_sheet_names = SubSheet::SUBSHEETS
    file = File.join('/home/yuva/Downloads/sheets_of_remote_url/OB_BluePoint_Mortgage_Wholesale6187.xls')
    xlsx = Roo::Spreadsheet.open(file)
    begin
      xlsx.sheets.each do |sheet|
        if (sheet == "Blue Point")
          @name = "BluePoint Mortgage"
          @bank = Bank.find_or_create_by(name: @name)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
        sub_sheet_names.each do |sub_sheet|
          @sub_sheet = @sheet.sub_sheets.create(name: sub_sheet)
        end
      end
    rescue
    end
  end

  def fha_streamline_programs
    @xlsx.sheets.each do |sheet|
      sheet_data  = @xlsx.sheet(sheet)
      BluePointMortgageService.new().implement_programs(138, 156, 140, [2, 6, 10], 143, 141, 156, 13, sheet_data)
    end

    redirect_to ob_blue_point_mortgage_wholesale6187_index_path
  end
end
