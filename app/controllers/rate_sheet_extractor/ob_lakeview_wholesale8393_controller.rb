class RateSheetExtractor::ObLakeviewWholesale8393Controller < RateSheetExtractor::ApplicationController
	include Wholesale
	before_action :get_sheet, only: [:programs, :program_property,:early_access,:asset_inclusion,:expanded_ratio,:alternative_income_calculation,:investor_product_no_prepayment_penalty,:bayview_portfolio_products,:piggy_back_second_lien_prepayment]
  before_action :get_program, only: [:single_program, :program_property]
  before_action :read_sheet, only: [:index,:programs,:early_access,:asset_inclusion,:expanded_ratio,:alternative_income_calculation,:investor_product_no_prepayment_penalty,:bayview_portfolio_products,:piggy_back_second_lien_prepayment]

  def index
  	sub_sheet_names = get_sheets_names
    begin
      @xlsx.sheets.each do |sheet|
        if (sheet == "Whsl Portfolio Ratesheet")
          headers = ["Phone", "General Contacts", "Mortgagee Clause (Wholesale)"]
          @name = "Bayview Loan Servicing"
          @bank = Bank.find_or_create_by(name: @name)
        end
        @sheet = @bank.sheets.find_or_create_by(name: sheet)
        sub_sheet_names.each do |sub_sheet|
          @sub_sheet = @sheet.sub_sheets.find_or_create_by(name: sub_sheet)
        end
      end
    rescue
      # the required headers are not all present
    end
  end

  def early_access
  	@programs_ids = []
 		@xlsx.sheets.each do |sheet|
      if (sheet == "Whsl Portfolio Ratesheet")
      	start_range = 13
      	end_range = 	70
      	count1 = 1
      	count2 = 2
      	num1 = 6
      	num2 = 5
      	cl1 = 0
      	cl2 = 0
      	cl3 = 0
      	cl4 = 0
      	cl5 = 0
      	cl6 = 0
      	make_program start_range, end_range, count1, count2, num1, num2, cl1, cl2, cl3, cl4, cl5, cl6
      end
    end
    redirect_to programs_ob_lakeview_wholesale8393_path(@sheet_obj)
  end

  def programs
    @programs = @sheet_obj.programs
  end

  def single_program
  end

  private

  def get_sheets_names
    return ["Early Access","Asset Inclusion","Expanded Ratio","Alternative Income Calculation","Investor Product NO Prepayment Penalty","Bayview Portfolio Products", "Piggy Back Second Lien Prepayment"]
  end

  def get_sheet
    @sheet_obj = SubSheet.find(params[:id])
  end

  def read_sheet
		file = File.join(Rails.root + "other_sheets", 'OB_Lakeview_Wholesale8393.xls')
    @xlsx = Roo::Spreadsheet.open(file)
  end

  def get_program
    @program = Program.find(params[:id])
  end
end