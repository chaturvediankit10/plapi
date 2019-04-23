module SheetOperation
  extend ActiveSupport::Concern

  included do
    before_action :get_sheet, only: [:fha_standard_programs, :fha_streamline_programs]
  end

  def fha_standard_programs
    @xlsx.sheets.each do |sheet|
      sheet_data  = @xlsx.sheet(sheet)

      # initial 9 parameters for first three table and last five parameters for another two table
      BluePointMortgageService.new().implement_programs(101, 119, 103, [2, 6, 10], 106, 104, 119, 13, sheet_data, 122, 134, [2, 6], 124, 8)
    end

    redirect_to ob_blue_point_mortgage_wholesale6187_index_path
  end

  private

  def get_sheet
    file = File.join(Rails.root,  'OB_BluePoint_Mortgage_Wholesale6187.xls')
    @xlsx  = Roo::Spreadsheet.open(file)
  end
end
